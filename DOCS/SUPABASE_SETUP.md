# Supabase Setup Guide

This guide will help you set up Supabase for the QR Attendance Scanner.

> **Note**: To completely remove this project from Supabase, see [SUPABASE_CLEANUP.md](SUPABASE_CLEANUP.md)

## Prerequisites

- A Supabase account (sign up at https://supabase.com)
- Your Google Sheet with student data

## Step 1: Create Supabase Project

1. Go to https://supabase.com and sign in
2. Click "New Project"
3. Fill in your project details:
   - Name: `qr-attendance-scanner` (or your preferred name)
   - Database Password: Choose a strong password (save it!)
   - Region: Choose closest to your users
4. Click "Create new project" and wait for it to be ready (~2 minutes)

## Step 2: Run Database Migration

1. In your Supabase project dashboard, go to **SQL Editor**
2. Click "New query"
3. Copy the contents of `supabase/migrations/001_create_students_table.sql`
4. Paste into the SQL editor
5. Click "Run" (or press Cmd/Ctrl + Enter)
6. Verify the `students` table was created by going to **Table Editor**

## Step 3: Deploy Edge Functions

### Option A: Using Supabase CLI (Recommended)

1. Install Supabase CLI:
   ```bash
   npm install -g supabase
   ```

2. Login to Supabase:
   ```bash
   supabase login
   ```

3. Link your project:
   ```bash
   supabase link --project-ref your-project-ref
   ```
   (Find your project ref in Supabase Dashboard > Settings > General)

4. Deploy edge functions:
   ```bash
   supabase functions deploy attendance-check
   supabase functions deploy sync-google-sheets
   supabase functions deploy attendance-stats-realtime
   ```
   
   **Note:** `attendance-stats-realtime` uses the database function for better performance with real-time subscriptions.

### Option B: Using Supabase Dashboard

1. Go to **Edge Functions** in your Supabase dashboard
2. For each function (`attendance-check`, `sync-google-sheets`, and `attendance-stats-realtime`):
   - Click "Create a new function"
   - Name it (e.g., `attendance-check`)
   - Copy the code from `supabase/functions/[function-name]/index.ts`
   - Paste into the editor
   - Click "Deploy"

## Step 4: Configure Environment Variables

### For Edge Functions:

1. Go to **Edge Functions** > **Settings**
2. Add the following secrets:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_SERVICE_ROLE_KEY`: Your service role key (from Settings > API)
   - `GOOGLE_SHEETS_API_KEY`: (Optional) If using Google Sheets API

### For Flutter App:

1. Open `qr_attendance_scanner/lib/config/supabase_config.dart`
2. Replace `YOUR_SUPABASE_URL` with your actual Supabase URL
3. Replace `YOUR_SUPABASE_ANON_KEY` with your anon/public key
4. Get these from: Supabase Dashboard > Settings > API

## Step 5: Sync Google Sheets Data

### Option A: Using the Edge Function

1. Make your Google Sheet public (View > Share > Anyone with the link can view)
2. Get your Google Sheet ID from the URL:
   ```
   https://docs.google.com/spreadsheets/d/[SHEET_ID]/edit
   ```
3. Call the sync function:
   ```bash
   curl -X POST \
     'https://your-project.supabase.co/functions/v1/sync-google-sheets' \
     -H 'Authorization: Bearer YOUR_ANON_KEY' \
     -H 'Content-Type: application/json' \
     -d '{
       "sheetId": "YOUR_SHEET_ID",
       "range": "A1:Z1000"
     }'
   ```

### Option B: Using Supabase Dashboard

1. Go to **Edge Functions** > `sync-google-sheets`
2. Click "Invoke function"
3. Enter JSON payload:
   ```json
   {
     "sheetId": "your-google-sheet-id",
     "range": "A1:Z1000"
   }
   ```
4. Click "Invoke"

## Step 6: Test the Setup

1. Run your Flutter app:
   ```bash
   cd qr_attendance_scanner
   flutter pub get
   flutter run
   ```

2. Scan a QR code and verify:
   - Student data is retrieved from Supabase
   - Attendance is marked correctly
   - Duplicate scans are detected

3. Enable Real-time Updates (Optional):
   - Go to Database > Replication in Supabase Dashboard
   - Enable replication for the `students` table
   - Run the migration: `supabase/migrations/002_add_realtime_stats.sql`
   - See `REALTIME_STATS_GUIDE.md` for implementation details

4. Test the attendance stats endpoint:
   ```bash
   curl -X POST \
     'https://your-project.supabase.co/functions/v1/attendance-stats-realtime' \
     -H 'Authorization: Bearer YOUR_ANON_KEY' \
     -H 'Content-Type: application/json'
   ```
   
   Expected response:
   ```json
   {
     "success": true,
     "data": {
       "total": 100,
       "attended": 45,
       "remaining": 55,
       "recent_24h": 12,
       "attendance_percentage": 45.00,
       "by_batch": {
         "Batch A": { "total": 50, "attended": 25, "remaining": 25 },
         "Batch B": { "total": 50, "attended": 20, "remaining": 30 }
       },
       "timestamp": "2024-01-01T12:00:00.000Z"
     }
   }
   ```

## Troubleshooting

### "QR token not found"
- Verify data was synced from Google Sheets
- Check the `students` table in Supabase Table Editor
- Ensure `qr_token` column has data

### "Failed to initialize Supabase"
- Check your Supabase URL and anon key in `supabase_config.dart`
- Ensure you're using the anon/public key, not the service role key

### Edge Function Errors
- Check Edge Functions logs in Supabase Dashboard
- Verify environment variables are set correctly
- Ensure RLS policies allow the operations

## Security Notes

- Never commit your Supabase service role key to version control
- The anon key is safe to use in client-side code
- Use RLS policies to restrict access as needed
- Consider adding authentication for the sync function

