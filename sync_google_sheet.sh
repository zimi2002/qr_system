#!/bin/bash

# Sync Google Sheet to Supabase
# Usage: ./sync_google_sheet.sh [SUPABASE_URL] [SUPABASE_ANON_KEY]

# Google Sheet ID extracted from the URL
SHEET_ID="1t6dzvF7dcAmrRIKrNVefWw9tixYY_tu76Mni54mlPuY"

# Get Supabase URL and key from arguments or environment
SUPABASE_URL="${1:-${SUPABASE_URL}}"
SUPABASE_ANON_KEY="${2:-${SUPABASE_ANON_KEY}}"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY are required"
  echo ""
  echo "Usage:"
  echo "  ./sync_google_sheet.sh [SUPABASE_URL] [SUPABASE_ANON_KEY]"
  echo ""
  echo "Or set environment variables:"
  echo "  export SUPABASE_URL='https://your-project.supabase.co'"
  echo "  export SUPABASE_ANON_KEY='your-anon-key'"
  echo "  ./sync_google_sheet.sh"
  exit 1
fi

echo "🔄 Syncing Google Sheet to Supabase..."
echo "📊 Sheet ID: $SHEET_ID"
echo "🔗 Supabase URL: $SUPABASE_URL"
echo ""

# Call the sync function
RESPONSE=$(curl -s -X POST \
  "${SUPABASE_URL}/functions/v1/sync-google-sheets" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"sheetId\": \"${SHEET_ID}\",
    \"range\": \"A1:Z1000\"
  }")

# Check if response contains success
if echo "$RESPONSE" | grep -q '"success":true'; then
  echo "✅ Sync completed successfully!"
  echo ""
  echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
else
  echo "❌ Sync failed!"
  echo ""
  echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
  exit 1
fi


