#!/usr/bin/env bash
set -euo pipefail

MODULE=$1

if [ -z "${MODULE:-}" ]; then
  echo "Module argument missing"
  exit 1
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "GEMINI_API_KEY not set"
  exit 1
fi

ROOT_DIR="$(pwd)"
cd "$MODULE"

if [ ! -f infracost.json ]; then
  echo "Missing infracost.json in $MODULE"
  exit 1
fi

if [ ! -f "$ROOT_DIR/.total_cost" ]; then
  echo "Missing .total_cost in root"
  exit 1
fi

TOTAL=$(cat "$ROOT_DIR/.total_cost")

RESOURCE_TYPES=$(jq -r '.resource_changes[].type' plan.json 2>/dev/null | sort -u | tr '\n' ', ' || echo "Unknown")

SUMMARY=$(jq -r '
  .projects[].breakdown.resources[] |
  "\(.name) | \(.monthlyCost)"
' infracost.json | head -n 50)

cat > prompt.txt <<EOF
ROLE: Senior GCP FinOps Architect (2026 Pricing Specialist)

Module: ${MODULE}
Direct Monthly Cost: ${TOTAL} USD
Resources: ${RESOURCE_TYPES}

Resource Cost Summary:
${SUMMARY}

If direct cost is 0, analyze usage-based shadow costs:
- NAT processing (0.045 USD/GB)
- Inter-zone egress (0.01 USD/GB)
- Logging ingestion (0.50 USD/GiB)
- Load balancer processing (0.008 USD/GB)

Return markdown tables only.
EOF

jq -n --rawfile text prompt.txt \
  '{contents:[{parts:[{text:$text}]}]}' \
  > gemini_request.json

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
