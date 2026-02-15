#!/usr/bin/env bash
set -euo pipefail

MODULE_PATH=$1
ROOT_DIR=$(pwd)

# Read shared artifacts from Root
TOTAL=$(cat "$ROOT_DIR/.total_cost")
INFRACOST_JSON=$(cat "$ROOT_DIR/.infracost_data.json")

# Determine Analysis Strategy
if (( $(echo "$TOTAL > 0" | bc -l) )); then
    STRATEGY="Direct Cost Optimization. Focus on: Spot Instances, Committed Use Discounts (CUDs), Graviton/ARM migration, and idle resource termination."
else
    STRATEGY="Shadow Cost Analysis (The 'Zero Cost' Trap). The direct cost is $0, which is suspicious. Analyze usage-based costs: NAT Gateway processing, Cross-zone networking (Egress), Log ingestion volume, and Storage API operations."
fi

# Construct the Prompt
cat > prompt.txt <<EOF
You are a Super-Intelligent GCP FinOps Architect (2026 Specialist).
Your goal is to save money and prevent hidden bill shock.

**ANALYSIS CONTEXT:**
- Module: $MODULE_PATH
- Estimated Monthly Cost: \$$TOTAL USD
- Strategy: $STRATEGY

**INSTRUCTIONS:**
1. Analyze the Infracost JSON below.
2. If cost > 0: Recommend specific optimizations (Spot, CUD, Rightsizing).
3. If cost = 0: You MUST warn about hidden "Shadow Costs" (Data transfer, API ops, Monitoring).
4. Be brief, professional, and use Markdown tables.

**INFRACOST DATA:**
$INFRACOST_JSON
EOF

# safely build JSON payload
jq -n --arg prompt "$(cat prompt.txt)" \
'{
  contents: [{
    parts: [{
      text: $prompt
    }]
  }]
}' > "$ROOT_DIR/gemini_request.json"

echo "🤖 Sending request to Gemini..."

RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  --data-binary @"$ROOT_DIR/gemini_request.json")

# Extract text safely
echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // "Error: Gemini API returned no content."' > "$ROOT_DIR/.gemini_output"

echo "✅ Gemini analysis complete."
