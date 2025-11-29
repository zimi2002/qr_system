# Sync Google Sheet to Supabase

This guide shows you how to sync your Google Sheet data to Supabase.

## Your Google Sheet

**Sheet ID:** `1t6dzvF7dcAmrRIKrNVefWw9tixYY_tu76Mni54mlPuY`  
**URL:** https://docs.google.com/spreadsheets/d/1t6dzvF7dcAmrRIKrNVefWw9tixYY_tu76Mni54mlPuY/edit

## Prerequisites

1. Make sure your Google Sheet is **public** (View > Share > Anyone with the link can view)
2. Have your Supabase URL and anon key ready
3. The `sync-google-sheets` edge function must be deployed

## Method 1: Using cURL (Quickest)

```bash
curl -X POST \
  'https://YOUR_PROJECT.supabase.co/functions/v1/sync-google-sheets' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "sheetId": "1t6dzvF7dcAmrRIKrNVefWw9tixYY_tu76Mni54mlPuY",
    "range": "A1:Z1000"
  }'
```

Replace:
- `YOUR_PROJECT` with your Supabase project reference
- `YOUR_ANON_KEY` with your Supabase anon/public key

## Method 2: Using the Shell Script

1. Make the script executable:
   ```bash
   chmod +x sync_google_sheet.sh
   ```

2. Run it:
   ```bash
   ./sync_google_sheet.sh https://YOUR_PROJECT.supabase.co YOUR_ANON_KEY
   ```

Or set environment variables:
```bash
export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
export SUPABASE_ANON_KEY="YOUR_ANON_KEY"
./sync_google_sheet.sh
```

## Method 3: Using Node.js Script

```bash
node sync_google_sheet.js https://YOUR_PROJECT.supabase.co YOUR_ANON_KEY
```

Or with environment variables:
```bash
export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
export SUPABASE_ANON_KEY="YOUR_ANON_KEY"
node sync_google_sheet.js
```

## Method 4: Using Supabase Dashboard

1. Go to **Edge Functions** in your Supabase dashboard
2. Click on `sync-google-sheets`
3. Click **Invoke function**
4. Enter this JSON payload:
   ```json
   {
     "sheetId": "1t6dzvF7dcAmrRIKrNVefWw9tixYY_tu76Mni54mlPuY",
     "range": "A1:Z1000"
   }
   ```
5. Click **Invoke**

## Method 5: Using Postman or Similar Tool

1. **Method:** POST
2. **URL:** `https://YOUR_PROJECT.supabase.co/functions/v1/sync-google-sheets`
3. **Headers:**
   - `Authorization`: `Bearer YOUR_ANON_KEY`
   - `Content-Type`: `application/json`
4. **Body** (JSON):
   ```json
   {
     "sheetId": "1t6dzvF7dcAmrRIKrNVefWw9tixYY_tu76Mni54mlPuY",
     "range": "A1:Z1000"
   }
   ```

## Expected Response

On success, you'll get:
```json
{
  "success": true,
  "message": "Sync completed",
  "stats": {
    "total_rows": 100,
    "inserted": 85,
    "updated": 15,
    "errors": 0
  }
}
```

## Troubleshooting

### "Failed to fetch Google Sheet"
- Make sure the sheet is **public** (View > Share > Anyone with the link can view)
- Check that the sheet ID is correct
- If using API key, ensure `GOOGLE_SHEETS_API_KEY` is set in edge function secrets

### "Column 'qr_token' not found"
- Ensure your sheet has the correct column headers:
  - Username
  - Name
  - Phone Number (optional)
  - Batch
  - Mentor Name
  - qr_token
  - url (optional)
  - sts
  - in_time
  - last_scan

### "Unauthorized" or 401 Error
- Check your Supabase anon key is correct
- Ensure you're using the anon/public key, not the service role key

### "Function not found" or 404 Error
- Make sure the `sync-google-sheets` edge function is deployed
- Check the function name is exactly `sync-google-sheets`

## Column Mapping

The sync function maps your Google Sheet columns to Supabase:

| Google Sheet Column | Supabase Column | Notes |
|---------------------|-----------------|-------|
| Username | username | Required |
| Name | name | Required |
| Phone Number | - | Not stored (optional) |
| Batch | batch | Optional |
| Mentor Name | mentor | Optional |
| qr_token | qr_token | Required, unique |
| url | - | Not stored (optional) |
| sts | sts | Default: 'inactive' |
| in_time | in_time | Timestamp |
| last_scan | last_scan | Timestamp |

## Re-syncing

You can run the sync multiple times. The function uses **upsert** logic:
- If a student with the same `qr_token` exists, it will be **updated**
- If a student doesn't exist, it will be **inserted**

This means you can safely re-sync without creating duplicates.

## Automation

To sync automatically, you can:
1. Set up a cron job to run the script periodically
2. Use GitHub Actions
3. Use a cloud scheduler (AWS Lambda, Google Cloud Functions, etc.)
4. Call it from your application when needed

## Next Steps

After syncing:
1. Verify data in Supabase Dashboard > Table Editor > students
2. Test the attendance scanner app
3. Check the stats page at `/stats` route

