#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
ROOT_DIR=$(pwd) # Track repository root

cd "$MODULE"
rm -f plan.tfplan plan.json infracost.json

terraform init -input=false
terraform plan -out=plan.tfplan -input=false
terraform show -json plan.tfplan > plan.json

infracost breakdown \
  --path plan.json \
  --format json \
  --out-file infracost.json

# Extract total and save to a hidden file in the root
TOTAL=$(jq '[.projects[].breakdown.totalMonthlyCost | tonumber] | add // 0' infracost.json)
echo "$TOTAL" > "$ROOT_DIR/.total_cost"

# Also copy the infracost JSON to the root so Gemini can find it easily
cp infracost.json "$ROOT_DIR/.infracost.json"
