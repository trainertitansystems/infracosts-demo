#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
ROOT_DIR=$(pwd)

cd "$MODULE"
rm -f plan.tfplan plan.json infracost.json

terraform init -input=false
terraform plan -out=plan.tfplan -input=false
terraform show -json plan.tfplan > plan.json

infracost breakdown \
  --path plan.json \
  --format json \
  --out-file infracost.json

# Extract total cost and save to root
TOTAL=$(jq '[.projects[].breakdown.totalMonthlyCost | tonumber] | add // 0' infracost.json)
echo "$TOTAL" > "$ROOT_DIR/.total_cost"

# Copy raw JSON to root for the Gemini script
cp infracost.json "$ROOT_DIR/.infracost.json"
