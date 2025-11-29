#!/bin/bash

# Diagnostic script for sync-google-sheets function
# This script tests the sync function and provides detailed error information

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SUPABASE_URL="https://pmboceqffjmcnsmsvepi.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/sync-google-sheets"
AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBtYm9jZXFmZmptY25zbXN2ZXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMzU0MDIsImV4cCI6MjA3OTgxMTQwMn0.1txDehngAJywpaIs1SVIlEWglCMpU1UGB4dWYquDUEs"
SHEET_ID="1t6dzvF7dcAmrRIKrNVefWw9tixYY_tu76Mni54mlPuY"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Sync Google Sheets Diagnostic Tool${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test 1: Check function endpoint
echo -e "${YELLOW}[Test 1] Checking function endpoint...${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST \
  "${FUNCTION_URL}" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"sheetId\": \"${SHEET_ID}\",
    \"range\": \"A1:Z10\"
  }")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
  echo -e "${GREEN}✓ Function endpoint is accessible${NC}"
else
  echo -e "${RED}✗ Function endpoint returned HTTP $http_code${NC}"
  echo "Response: $body"
  exit 1
fi

# Test 2: Parse response and show stats
echo ""
echo -e "${YELLOW}[Test 2] Parsing sync response...${NC}"
echo "$body" | jq '.' 2>/dev/null || echo "$body"

# Extract error details if present
error_count=$(echo "$body" | jq -r '.stats.errors // 0' 2>/dev/null || echo "0")
error_details=$(echo "$body" | jq -r '.error_details // []' 2>/dev/null || echo "[]")

if [ "$error_count" -gt 0 ]; then
  echo ""
  echo -e "${RED}========================================${NC}"
  echo -e "${RED}ERRORS DETECTED: $error_count${NC}"
  echo -e "${RED}========================================${NC}"
  echo ""
  
  if [ "$error_details" != "[]" ] && [ "$error_details" != "null" ]; then
    echo -e "${YELLOW}Error Details:${NC}"
    echo "$error_details" | jq '.' 2>/dev/null || echo "$error_details"
  else
    echo -e "${YELLOW}No detailed error information available.${NC}"
    echo -e "${YELLOW}Check Supabase function logs for more details.${NC}"
  fi
else
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}SYNC COMPLETED SUCCESSFULLY${NC}"
  echo -e "${GREEN}========================================${NC}"
fi

# Test 3: Check database connection (if Supabase CLI is available)
echo ""
echo -e "${YELLOW}[Test 3] Checking database schema...${NC}"
if command -v supabase &> /dev/null; then
  echo "Supabase CLI found. Checking students table structure..."
  # This would require proper Supabase project setup
  echo "Note: Run 'supabase db inspect' to check table structure"
else
  echo "Supabase CLI not found. Skipping database inspection."
fi

# Test 4: Validate sample data structure
echo ""
echo -e "${YELLOW}[Test 4] Validating data requirements...${NC}"
echo "Required fields in students table:"
echo "  - username (TEXT NOT NULL)"
echo "  - name (TEXT NOT NULL)"
echo "  - qr_token (TEXT UNIQUE NOT NULL)"
echo ""
echo "Optional fields:"
echo "  - batch (TEXT)"
echo "  - mentor (TEXT)"
echo "  - sts (TEXT, default: 'inactive')"
echo "  - in_time (TIMESTAMP)"
echo "  - last_scan (TIMESTAMP)"

# Test 5: Small batch test
echo ""
echo -e "${YELLOW}[Test 5] Testing with small range (first 5 rows)...${NC}"
small_test=$(curl -s -X POST \
  "${FUNCTION_URL}" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"sheetId\": \"${SHEET_ID}\",
    \"range\": \"A1:Z5\"
  }")

echo "$small_test" | jq '.' 2>/dev/null || echo "$small_test"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Diagnostic Complete${NC}"
echo -e "${BLUE}========================================${NC}"


