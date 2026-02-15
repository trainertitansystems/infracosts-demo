#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
PR=$2

# Load results from root
TOTAL=$(cat .total_cost)
AI=$(cat .gemini_output)

cat > comment.md <<EOF
## 💰 Terraform Cost Analysis (\`$MODULE\`)

| Metric | Estimated Value |
|:-------|:----------------|
| **Direct Monthly Cost** | **\$$TOTAL USD** |

---

## 🤖 Gemini AI FinOps Review

$AI

---
*Note: Analyzed by Gemini 2.0 Flash Agent*
EOF

# Post the comment using the GitHub CLI
gh pr comment "$PR" --body-file comment.md
