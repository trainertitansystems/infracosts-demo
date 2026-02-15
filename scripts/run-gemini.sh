#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
ROOT_DIR=$(pwd)

# Load total cost from root
TOTAL=$(cat "$ROOT_DIR/.total_cost")

# Detect resource types for context
RESOURCE_TYPES=$(jq -r '.resource_changes[].type' "$MODULE/plan.json" | sort -u | tr '\n' ', ' || echo "None")

# 1. Build the prompt in a temporary file to avoid shell expansion issues
cat > prompt.txt <<EOF
ROLE: Super-Intelligent GCP FinOps Architect (2026 Specialist)
TASK: Analyze cost exposure for Module: $MODULE.

METRICS:
- Direct Monthly Cost: \$${TOTAL} USD
- Resources: $RESOURCE_TYPES

INSTRUCTIONS:
- If cost > 0: Analyze if these support Spot Instances, CUDs, or Tiered Pricing.
- If cost == 0: Identify "Shadow Costs" (Egress, NAT processing, Logging ingestion).
- Format output as professional Markdown with tables.

RAW INFRACOST DATA:
$(cat "$ROOT_DIR/.infracost.json")
EOF

# 2. Use jq --rawfile to safely build the JSON payload
# This prevents the "Unexpected token" error caused by heredoc expansion.
jq -n --rawfile p prompt.txt '{contents: [{parts: [{text: $p}]}]}' > "$ROOT_DIR/gemini_request.json"

# 3. POST to Gemini API
RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data-binary @"$ROOT_DIR/gemini_request.json")

# Extract response safely
AI_TEXT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty')

if [ -z "$AI_TEXT" ]; then
    echo "❌ API Error: $(echo "$RESPONSE" | jq -r '.error.message // "Unknown Error"')" >&2
    echo "Gemini Analysis Unavailable (Check logs for API error)" > "$ROOT_DIR/.gemini_output"
else
    echo "$AI_TEXT" > "$ROOT_DIR/.gemini_output"
fi
