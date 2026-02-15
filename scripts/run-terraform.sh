#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
ROOT_DIR=$(pwd) # Capture root directory absolute path

cd "$MODULE"
rm -f plan.tfplan plan.json infracost.json

terraform init -input=false
terraform plan -out=plan.tfplan -input=false
terraform show -json plan.tfplan > plan.json

infracost breakdown \
  --path plan.json \
  --format json \
  --out-file infracost.json

TOTAL=$(jq '[.projects[].breakdown.totalMonthlyCost | tonumber] | add // 0' infracost.json)

# Fix: Use absolute path to root
echo "$TOTAL" > "$ROOT_DIR/.total_cost"
