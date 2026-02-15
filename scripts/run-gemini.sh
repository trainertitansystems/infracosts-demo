#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
ROOT_DIR=$(pwd)

# Load cost from root
TOTAL=$(cat "$ROOT_DIR/.total_cost")

cd "$MODULE"
# Capture resource types or default to None
RESOURCE_TYPES=$(jq -r '.resource_changes[].type' plan.json | sort -u | tr '\n' ', ' || echo "None")

# Construct the "Super Intelligent" prompt
cat > prompt.txt <<EOF
ROLE: Super-Intelligent GCP FinOps Architect (2026 Specialist)
TASK: Perform a deep financial audit of module: $MODULE.

METRICS:
- Direct Monthly Cost: \$${TOTAL} USD
- Involved Resources: $RESOURCE_TYPES

INSTRUCTIONS:
1. If Direct Cost > 0: Identify optimization strategies (Spot instances, CUDs, Rightsizing).
2. If Direct Cost == 0: Conduct a "Shadow Cost" audit. Analyze potential exposure in:
   - Network: Egress, NAT Gateway processing, Inter-zone traffic.
   - Serverless: Cloud Run concurrency/cold starts.
   - Observability: Log ingestion and high-cardinality monitoring.

OUTPUT: Provide markdown tables and bold risk highlights only.

INFRACOST DATA:
$(cat infracost.json)
EOF

# Use jq to safely escape the prompt text into a JSON payload
jq -n --arg msg "$(cat prompt.txt)" '{contents: [{parts: [{text: $msg}]}]}' > "$ROOT_DIR/gemini_request.json"

# POST request with header-based auth
RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data-binary @"$ROOT_DIR/gemini_request.json")

# Extract response or actual API error message for debugging
AI_OUTPUT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty')

if [ -z "$AI_OUTPUT" ]; then
    # Capture the raw error from the API if candidates are missing
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown API Error"')
    echo "❌ Gemini API Error: $ERROR_MSG" >&2
    echo "⚠️ **FinOps Analysis Error**: $ERROR_MSG" > "$ROOT_DIR/.gemini_output"
else
    echo "$AI_OUTPUT" > "$ROOT_DIR/.gemini_output"
fi
