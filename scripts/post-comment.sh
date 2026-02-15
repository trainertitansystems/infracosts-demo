#!/usr/bin/env bash
set -euo pipefail

MODULE=$1
PR=$2

TOTAL=$(cat .total_cost)
AI=$(cat .gemini_output)

cat > comment.md <<EOF
## Terraform Cost Analysis ($MODULE)

| Field | Value |
|-------|-------|
| Direct Monthly Cost | \$$TOTAL USD |

---

## Gemini AI FinOps Review

$AI
EOF

gh pr comment "$PR" --body-file comment.md

