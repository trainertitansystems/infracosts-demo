#!/usr/bin/env bash
set -euo pipefail

MODULE_PATH=$1
ROOT_DIR=$(pwd)

echo "🔍 Starting Terraform Analysis for: $MODULE_PATH"

cd "$MODULE_PATH"

# Clean previous local artifacts
rm -f plan.tfplan plan.json

# Init and Plan
terraform init -input=false -backend=false
terraform plan -out=plan.tfplan -input=false
terraform show -json plan.tfplan > plan.json

# Run Infracost
infracost breakdown \
  --path plan.json \
  --format json \
  --out-file infracost_output.json

# Save key data to ROOT_DIR for the next script
# 1. Save the full JSON for Gemini
cp infracost_output.json "$ROOT_DIR/.infracost_data.json"

# 2. Extract total monthly cost
TOTAL=$(jq '[.projects[].breakdown.totalMonthlyCost | tonumber] | add // 0' infracost_output.json)
echo "$TOTAL" > "$ROOT_DIR/.total_cost"

echo "✅ Cost calculated: \$$TOTAL"
