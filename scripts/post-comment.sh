#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
PR=$2

# Load artifacts from the root
TOTAL=$(cat .total_cost)
AI=$(cat .gemini_output)

cat > comment.md <<EOF
## 💰 Terraform Cost Analysis (\`$MODULE\`)

| Metric | Estimated Monthly Impact |
|:-------|:-------------------------|
| **Direct Monthly Cost** | \$$TOTAL USD |

---

## 🤖 Gemini AI FinOps Review

$AI

---
*Note: Analyzed by Gemini 2.0 Flash FinOps Agent.*
EOF

gh pr comment "$PR" --body-file comment.md
