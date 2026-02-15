#!/usr/bin/env bash
set -euo pipefail

MODULE=$1

cd "$MODULE"

if [ ! -f "infracost.json" ]; then
  echo "Missing infracost.json in $MODULE"
  exit 1
fi

# Compute total safely here (no external dependency)
TOTAL=$(jq '[.projects[].breakdown.totalMonthlyCost | tonumber] | add // 0' infracost.json)

# Build compact summary
SUMMARY=$(jq -r '
  .projects[].breakdown.resources[]? |
  "\(.name) | \(.monthlyCost)"
' infracost.json | head -n 50 || true)

cat > prompt.txt <<EOF
ROLE: Senior GCP FinOps Architect (2026 Pricing Specialist)

Module: ${MODULE}
Direct Monthly Cost: ${TOTAL} USD

Resources Summary:
${SUMMARY}

If direct cost is 0, analyze usage-based shadow costs:
- NAT processing (0.045 USD/GB)
- Inter-zone egress (0.01 USD/GB)
- Logging ingestion (0.50 USD/GiB)
- Load balancer processing (0.008 USD/GB)

Return markdown tables only.
EOF

# Safe JSON generation
jq -Rs '{contents:[{parts:[{text:.}]}]}' prompt.txt > gemini_request.json

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

echo "Gemini completed for module: $MODULE"
