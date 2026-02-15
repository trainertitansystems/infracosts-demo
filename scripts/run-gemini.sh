#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
cd "$MODULE"

TOTAL=$(cat ../.total_cost)
RESOURCE_TYPES=$(jq -r '.resource_changes[].type' plan.json | sort -u | tr '\n' ', ')

cat > prompt.txt <<EOF
ROLE: Senior GCP FinOps Architect (2026 Specialist)

Analyze direct and hidden cost exposure.

Module: $MODULE
Direct Monthly Cost: $TOTAL USD
Resources: $RESOURCE_TYPES

If direct cost is 0, analyze usage-based shadow costs:
- NAT processing
- Egress
- Inter-zone traffic
- Logging ingestion
- Load balancer processing

Return markdown tables only.

Infracost JSON:
$(cat infracost.json)
EOF

# Proper JSON creation using jq to escape text safely
cat > ../gemini_request.json <<EOF
{
  "contents": [
    {
      "parts": [
        { "text": $(jq -Rs . < prompt.txt) }
      ]
    }
  ]
}
EOF

RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data-binary @../gemini_request.json)

echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // "Gemini Error"' > ../.gemini_output
