#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
ROOT_DIR=$(pwd)
TOTAL=$(cat "$ROOT_DIR/.total_cost")

# 1. Build the prompt string SAFELY using jq
# This replaces the 'cat <<EOF' method which was causing the JSON errors.
PROMPT_HEADER="You are a Senior GCP FinOps Architect. Analyze this Terraform cost breakdown for module: $MODULE."
PROMPT_METRICS="Total Monthly Cost: \$$TOTAL USD. Instructions: suggest Spot/CUD if cost > 0, otherwise highlight shadow costs."

# Use jq to merge the strings and the file content into a single JSON request
jq -n \
  --arg header "$PROMPT_HEADER" \
  --arg metrics "$PROMPT_METRICS" \
  --rawfile data "$ROOT_DIR/.infracost.json" \
  '{
    contents: [{
      parts: [{
        text: ($header + "\n" + $metrics + "\n\nRAW DATA:\n" + $data)
      }]
    }]
  }' > "$ROOT_DIR/gemini_request.json"

# 2. POST to Gemini API
RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data-binary @"$ROOT_DIR/gemini_request.json")

# 3. Extract AI text or handle API errors
AI_RESULT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty')

if [ -z "$AI_RESULT" ]; then
    # Capture detailed error from Google if it fails
    ERR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown API Error"')
    echo "❌ API Error Details: $ERR_MSG" >&2
    echo "⚠️ **FinOps Analysis Error**: $ERR_MSG" > "$ROOT_DIR/.gemini_output"
else
    echo "$AI_RESULT" > "$ROOT_DIR/.gemini_output"
fi
