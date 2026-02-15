#!/usr/bin/env bash
set -euo pipefail

MODULE="$1"
ROOT_DIR=$(pwd)

echo "🚀 Starting FinOps Audit for module: $MODULE"

# Go to module directory
cd "$MODULE"

# Cleanup old artifacts
rm -f plan.tfplan plan.json infracost.json gemini.md prompt.txt gemini_request.json

echo "📦 Running Terraform..."
terraform init -input=false
terraform plan -out=plan.tfplan -input=false
terraform show -json plan.tfplan > plan.json

echo "💰 Running Infracost..."
infracost breakdown \
  --path plan.json \
  --format json \
  --out-file infracost.json

# Extract total monthly cost
TOTAL=$(jq '[.projects[].breakdown.totalMonthlyCost | tonumber] | add // 0' infracost.json)

echo "Total monthly cost: $TOTAL"

# ----------------------------
# Build Gemini Prompt
# ----------------------------

cat > prompt.txt <<EOF
You are a Senior GCP FinOps Architect.

Module: $MODULE
Direct Monthly Cost: $TOTAL USD

Analyze ALL Terraform resources.

If direct cost is 0, DO NOT simply say zero.
Explain possible usage-based shadow costs such as:
- network egress
- NAT processing
- logging ingestion
- load balancer data processing
- autoscaling exposure

Provide:
1) Cost classification (Fixed or Usage-Based)
2) Shadow cost explanation
3) Risk rating
4) Optimization recommendation

Return markdown tables only.
EOF

# Convert safely to JSON
jq -n --rawfile text prompt.txt \
  '{contents:[{parts:[{text:$text}]}]}' \
  > gemini_request.json

echo "🤖 Calling Gemini API..."

RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data-binary @gemini_request.json || echo "CURL_ERROR")

# Always create gemini.md
if [[ "$RESPONSE" == "CURL_ERROR" ]]; then
  echo "Gemini API Error: Connection Failed" > gemini.md
elif echo "$RESPONSE" | jq -e '.candidates' >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text' > gemini.md
else
  echo "Gemini API Error" > gemini.md
fi

# Go back to root for PR comment
cd "$ROOT_DIR"

# ----------------------------
# Post PR Comment
# ----------------------------

{
  echo "## 💰 FinOps Audit: $MODULE"
  echo ""
  echo "| Field | Value |"
  echo "|-------|-------|"
  echo "| Direct Monthly Cost | \$${TOTAL} USD |"
  echo ""
  echo "## 🤖 Gemini Architect Review"
  echo ""
  cat "$MODULE/gemini.md"
  echo ""
  echo "---"
  echo "Generated via Gemini 2.0 Flash + Infracost"
} > comment.md

gh pr comment "$PR_NUMBER" --body-file comment.md

echo "✅ FinOps review completed for $MODULE"

