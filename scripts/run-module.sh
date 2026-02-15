#!/usr/bin/env bash
set -euo pipefail

MODULE="$1"

echo "Processing module: $MODULE"

cd "$MODULE"

rm -f plan.tfplan plan.json infracost.json gemini.md prompt.txt gemini_request.json

terraform init -input=false
terraform plan -out=plan.tfplan -input=false
terraform show -json plan.tfplan > plan.json

infracost breakdown \
  --path plan.json \
  --format json \
  --out-file infracost.json

TOTAL=$(jq '[.projects[].breakdown.totalMonthlyCost | tonumber] | add // 0' infracost.json)

echo "Total monthly cost: $TOTAL"

# ---------- Build Gemini prompt safely ----------
cat > prompt.txt <<EOF
You are a Senior GCP FinOps Architect.

Module: $MODULE
Direct Monthly Cost: $TOTAL USD

Analyze ALL Terraform resources.

If direct cost is 0, do NOT say zero.
Explain usage-based shadow costs such as:
- network egress
- NAT processing
- logging ingestion
- load balancer data processing
- scaling exposure

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

# ---------- Call Gemini safely ----------
RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data-binary @gemini_request.json)

echo "$RESPONSE" | jq -r '
  if .candidates then
    .candidates[0].content.parts[0].text
  else
    "Gemini API Error"
  end
' > gemini.md

cd ..

# ---------- Post PR Comment ----------
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
} > comment.md

gh pr comment "$PR_NUMBER" --body-file comment.md

echo "FinOps review completed."

