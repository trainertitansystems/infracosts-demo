#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
ROOT_DIR=$(pwd)

echo "Starting Infracost for $MODULE..."

cd "$MODULE"
rm -f plan.tfplan plan.json infracost.json

terraform init -input=false
terraform plan -out=plan.tfplan -input=false
terraform show -json plan.tfplan > plan.json

infracost breakdown \
  --path plan.json \
  --format json \
  --out-file infracost.json

# Extract total monthly cost
TOTAL=$(jq '[.projects[].breakdown.totalMonthlyCost | tonumber] | add // 0' infracost.json)

# Save to absolute root path to avoid directory depth issues
echo "$TOTAL" > "$ROOT_DIR/.total_cost"
