#!/usr/bin/env bash
set -e

MODULE="$1"
PR_NUMBER="$2"

TOTAL_FILE="${MODULE}/.total_cost"
GEMINI_FILE="${MODULE}/.gemini_output"

if [ ! -f "$TOTAL_FILE" ]; then
  echo "Missing total cost file: $TOTAL_FILE"
  exit 1
fi

if [ ! -f "$GEMINI_FILE" ]; then
  echo "Missing Gemini output file: $GEMINI_FILE"
  exit 1
fi

TOTAL=$(cat "$TOTAL_FILE")

{
  echo "## 💰 Terraform Cost Analysis (${MODULE})"
  echo ""
  echo "| Field | Value |"
  echo "| :--- | :--- |"
  echo "| Direct Monthly Cost | \$${TOTAL} USD |"
  echo ""
  echo "---"
  echo ""
  echo "## 🤖 Gemini AI FinOps Intelligence"
  echo ""
  cat "$GEMINI_FILE"
} > comment.md

gh pr comment "$PR_NUMBER" --body-file comment.md
