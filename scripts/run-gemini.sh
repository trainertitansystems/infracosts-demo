#!/usr/bin/env bash
set -euo pipefail

MODULE=$1

cd "$MODULE"

if [ ! -f ".total_cost" ]; then
  echo "Missing total cost file: $MODULE/.total_cost"
  exit 1
fi

if [ ! -f "infracost.json" ]; then
  echo "Missing infracost.json in $MODULE"
  exit 1
fi

TOTAL=$(cat .total_cost)

RESOURCE_TYPES=$(jq -r '.resource_changes[].type' plan.json 2>/dev/null | sort -u | tr '\n' ', ' || true)

# Build compact summary from Infracost
SUMMARY=$(jq -r '
  .projects[].breakdown.resources[]? |
  "\(.name) | \(.monthlyCost)"
' infracost.json | head -n 50 || true)

rm -f .gemini_output
rm -f gemini_request.json
rm -f prompt.txt

cat > prompt.txt <<EOF
ROLE: Senior GCP FinOps Architect (2026 Pricing Specialist)

Module: ${MODULE}
Direct Monthly Cost: ${TOTAL} USD
Resources: ${RESOURCE_TYPES}

Resources Summary:
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
' > .gemini_output

echo "Gemini analysis completed for module: $MODULE"
