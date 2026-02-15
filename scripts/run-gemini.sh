# Build compact resource summary (avoid huge payloads)
SUMMARY=$(jq -r '
  .projects[].breakdown.resources[] |
  "\(.name) | \(.monthlyCost)"
' infracost.json | head -n 50)

# Build prompt safely
cat > prompt.txt <<EOF
ROLE: Senior GCP FinOps Architect (2026 Pricing Specialist)

TASK:
Analyze this Terraform module for BOTH direct and hidden cloud cost risks.

Module: ${MODULE}
Direct Monthly Cost (Infracost): ${TOTAL} USD

Resources Summary:
${SUMMARY}

If direct cost is 0, evaluate usage-based shadow costs including:
- Cloud NAT processing (0.045 USD/GB)
- Inter-zone egress (0.01 USD/GB)
- Logging ingestion (0.50 USD/GiB)
- Load balancer processing (0.008 USD/GB)

Return:
1. Fixed Monthly Floor
2. Usage-Based Risk Exposure
3. Production Forecast Range
4. Risk Rating (Low | Medium | High)

Output strictly in markdown tables.
EOF

# Convert to valid Gemini JSON
jq -Rs '{contents:[{parts:[{text:.}]}]}' prompt.txt > gemini_request.json

# Call Gemini safely
RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: ${GEMINI_API_KEY}" \
  --data @gemini_request.json)

# Extract response cleanly
echo "$RESPONSE" | jq -r '
  if .candidates then
    .candidates[0].content.parts[0].text
  elif .error then
    "Gemini API Error: " + .error.message
  else
    "Unknown Gemini Response"
  end
' > ../.gemini_output
