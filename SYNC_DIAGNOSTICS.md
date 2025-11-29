# Sync Google Sheets - Diagnostics Guide

## Overview
This document explains the sync-google-sheets function and how to diagnose issues.

## Recent Changes

### 1. Insert-Only Mode
- The function now **only inserts new records** and **does not update existing ones**
- Existing records (based on `qr_token`) are automatically skipped
- Duplicate `qr_token` values within the sheet itself are also filtered out

### 2. Improved Error Handling
- Better error detection and reporting
- Error details are now included in the response (first 10 errors)
- More accurate counting of successful inserts vs errors

### 3. Data Validation
- Rows with missing `username` or `name` (required fields) are skipped
- Empty `qr_token` values are filtered out

## Diagnostic Tools

### 1. Bash Script (`test-sync-diagnostic.sh`)
A comprehensive bash script that tests the sync function:

```bash
./test-sync-diagnostic.sh
```

**Features:**
- Tests function endpoint accessibility
- Parses and displays sync statistics
- Shows error details if any
- Tests with small batch (10 rows) first
- Validates data requirements

### 2. Node.js Script (`diagnose-sync.js`)
A more detailed diagnostic tool with better error parsing:

```bash
node diagnose-sync.js
```

**Features:**
- Tests with small batch (10 rows)
- Tests full sync
- Displays detailed statistics
- Shows error details with codes, messages, and hints
- Better formatted output

## Understanding the Response

### Success Response
```json
{
  "success": true,
  "message": "Sync completed",
  "stats": {
    "total_rows": 3067,
    "processed": 2061,
    "inserted": 2061,
    "skipped": 1000,
    "errors": 0
  }
}
```

### Response with Errors
```json
{
  "success": false,
  "message": "Sync completed with errors",
  "stats": {
    "total_rows": 3067,
    "processed": 2061,
    "inserted": 0,
    "skipped": 1000,
    "errors": 2061
  },
  "error_details": [
    {
      "batch": 1,
      "error": "Error message here",
      "code": "23505",
      "details": "Additional details",
      "hint": "Helpful hint",
      "batch_size": 50
    }
  ],
  "total_error_batches": 42
}
```

## Common Issues and Solutions

### Issue: All inserts showing as errors
**Possible causes:**
1. **Missing required fields**: Check that `username` and `name` columns exist and have data
2. **Data type mismatches**: Ensure timestamps are in correct format
3. **Constraint violations**: Check for unique constraint violations on `qr_token`
4. **RLS policies**: Verify that insert policies allow the operation

**Solution:**
- Run the diagnostic script to see actual error messages
- Check Supabase function logs for detailed error information
- Verify the Google Sheet has all required columns

### Issue: Records not being inserted
**Possible causes:**
1. Records already exist in database (they're being skipped)
2. Missing required fields (`username` or `name`)
3. Duplicate `qr_token` values in the sheet

**Solution:**
- Check the `skipped` count in the response
- Verify data in Google Sheet has all required fields
- Check for duplicate `qr_token` values in the sheet

### Issue: Partial inserts
**Possible causes:**
1. Some records have missing required fields
2. Some `qr_token` values are duplicates
3. Some records violate constraints

**Solution:**
- Review error_details in the response
- Check which batches failed
- Verify data quality in Google Sheet

## Database Schema Requirements

The `students` table requires:
- `username` (TEXT NOT NULL) - **Required**
- `name` (TEXT NOT NULL) - **Required**
- `qr_token` (TEXT UNIQUE NOT NULL) - **Required, must be unique**
- `batch` (TEXT) - Optional
- `mentor` (TEXT) - Optional
- `sts` (TEXT) - Optional, defaults to 'inactive'
- `in_time` (TIMESTAMP) - Optional
- `last_scan` (TIMESTAMP) - Optional

## Testing the Sync

### Quick Test (10 rows)
```bash
curl -X POST \
  'https://pmboceqffjmcnsmsvepi.supabase.co/functions/v1/sync-google-sheets' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "sheetId": "YOUR_SHEET_ID",
    "range": "A1:Z10"
  }'
```

### Full Sync
```bash
curl -X POST \
  'https://pmboceqffjmcnsmsvepi.supabase.co/functions/v1/sync-google-sheets' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "sheetId": "YOUR_SHEET_ID",
    "range": "A1:Z1000"
  }'
```

## Next Steps if Errors Persist

1. **Run diagnostic scripts** to get detailed error information
2. **Check Supabase logs** for function execution logs
3. **Verify Google Sheet structure** matches expected format
4. **Test with a small batch** first to isolate issues
5. **Check database constraints** and RLS policies

## Notes

- The function processes data in batches of 50 records
- Duplicate `qr_token` values are automatically filtered (first occurrence is kept)
- Records with missing required fields are skipped
- The function uses `ignoreDuplicates: true` to handle race conditions gracefully

