#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
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

echo "$TOTAL" > ../.total_cost

