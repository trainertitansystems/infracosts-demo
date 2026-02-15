#!/usr/bin/env bash
set -euo pipefail

MODULE="$1"

cd "$MODULE"

if [ ! -f infracost.json ]; then
  echo "No infracost.json found"
  echo "Gemini skipped - no cost data" > gemini.md
  exit 0
fi

TOTAL=$(jq '[.projects[].breakdown.totalMonthlyCost | tonumber] | add // 0' infracost.json)

# Build minimal, safe prompt
cat > prompt.txt <<EOF
You are a GCP FinOps Architect.

Direct Monthly Cost: ${TOTAL} USD

If cost is usage-based, explain potential shadow costs such as:
- Network egress
- NAT processing
- Logging
- Inter-zone traffic

Provide simple markdown table with:
Component | Risk | Recommendation
EOF

jq -n --rawfile text prompt.txt \
  '{contents:[{parts:[{text:$text}]}]}' > gemini_request.json

# Call Gemini safely
RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data-binary @gemini_request.json || true)

# Always create gemini.md
if echo "$RESPONSE" | jq -e '.candidates' >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text' > gemini.md
else
  echo "Gemini API Error" > gemini.md
fi

echo "Gemini completed for module: $MODULE"
