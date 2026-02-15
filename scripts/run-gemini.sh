#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
ROOT_DIR="$(pwd)"

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "GEMINI_API_KEY not set"
  exit 1
fi

cd "$MODULE"

TOTAL=$(cat "$ROOT_DIR/.total_cost")

# Extract safe summary instead of raw JSON
RESOURCE_TYPES=$(jq -r '.resource_changes[].type' plan.json 2>/dev/null | sort -u | tr '\n' ', ' || echo "Unknown")

SUMMARY=$(jq -r '
  .projects[].breakdown.resources[] |
  "\(.name): $\(.monthlyCost)"
' infracost.json | head -n 50)

cat > gemini_request.json <<EOF
{
  "contents": [
    {
      "parts": [
        {
          "text": "ROLE: Senior GCP FinOps Architect (2026 Pricing Specialist)

Module: ${MODULE}
Direct Monthly Cost: ${TOTAL} USD
Resources: ${RESOURCE_TYPES}

Resource Cost Summary:
${SUMMARY}

If direct cost is 0 USD, analyze usage-based shadow costs:
- NAT processing (0.045 USD per GB)
- Inter-zone egress (0.01 USD per GB)
- Logging ingestion (0.50 USD per GiB)
- Load balancer processing (0.008 USD per GB)

Return markdown tables only."
        }
      ]
    }
  ]
}
EOF

RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data-binary @gemini_request.json)

echo "$RESPONSE" | jq -r '
  if .candidates then
    .candidates[0].content.parts[0].text
  elif .error then
    "Gemini API Error: " + .error.message
  else
    "Unknown Gemini Response"
  end
' > "$ROOT_DIR/.gemini_output"

echo "Gemini completed for module: $MODULE"
