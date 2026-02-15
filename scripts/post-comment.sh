#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
PR=$2

TOTAL=$(cat .total_cost)
AI=$(cat .gemini_output)

cat > comment.md <<EOF
## 💰 FinOps Audit: \`$MODULE\`
**Direct Monthly Cost:** \$$TOTAL USD

---
### 🤖 Gemini Architect Review
$AI

---
*Generated via Gemini 2.0 Flash + Infracost*
EOF

gh pr comment "$PR" --body-file comment.md
