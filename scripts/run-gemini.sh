#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
ROOT_DIR=$(pwd)

# Read total cost from root
TOTAL=$(cat "$ROOT_DIR/.total_cost")

cd "$MODULE"
RESOURCE_TYPES=$(jq -r '.resource_changes[].type' plan.json | sort -u | tr '\n' ', ' || echo "None")

cat > prompt.txt <<EOF
ROLE: Senior GCP FinOps Architect (2026 Specialist)
Analyze direct and hidden cost exposure for Module: $MODULE.

Direct Monthly Cost: $TOTAL USD
Resources: $RESOURCE_TYPES

If direct cost is 0, analyze usage-based shadow costs (NAT, Egress, Logging).
Return markdown tables only.

Infracost JSON:
$(cat infracost.json)
EOF

# Proper JSON creation to escape characters safely
jq -n --arg prompt "$(cat prompt.txt)" \
  '{contents: [{parts: [{text: $prompt}]}]}' > "$ROOT_DIR/gemini_request.json"

# Fix: Header-based auth for Gemini API
RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data-binary @"$ROOT_DIR/gemini_request.json")

echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // "Gemini Error"' > "$ROOT_DIR/.gemini_output"
