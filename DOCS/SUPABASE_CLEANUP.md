# Supabase Project Cleanup Guide

This guide will help you completely remove the QR Attendance Scanner project from your Supabase instance.

⚠️ **WARNING**: This will permanently delete all data, tables, functions, and edge functions. Make sure you have backups if you need to preserve any data.

## Prerequisites

- Access to your Supabase project dashboard
- SQL Editor access
- Edge Functions deployment access (if using CLI)

## Step 1: Backup Data (Optional but Recommended)

Before deleting everything, you may want to export your data:

### Export Students Data

1. Go to **Table Editor** > `students` table
2. Click the **Export** button (or use SQL):
   ```sql
   -- Export to CSV
   COPY students TO '/tmp/students_backup.csv' WITH CSV HEADER;
   ```

Or use Supabase Dashboard:
- Go to **Table Editor** > `students`
- Click **Export** > Choose format (CSV/JSON)

## Step 2: Remove Edge Functions

### Option A: Using Supabase CLI

```bash
# Delete edge functions
supabase functions delete attendance-check
supabase functions delete sync-google-sheets
supabase functions delete attendance-stats-realtime
```

### Option B: Using Supabase Dashboard

1. Go to **Edge Functions** in your Supabase dashboard
2. For each function:
   - Click on the function name
   - Click **Delete** or **Remove**
   - Confirm deletion

Functions to delete:
- `attendance-check`
- `sync-google-sheets`
- `attendance-stats-realtime`

## Step 3: Remove Database Objects

Run this SQL script in the **SQL Editor** to remove all database objects:

```sql
-- ============================================
-- COMPLETE CLEANUP SCRIPT
-- Run this in Supabase SQL Editor
-- ============================================

-- Step 1: Drop triggers
DROP TRIGGER IF EXISTS attendance_change_notifier ON students;
DROP TRIGGER IF EXISTS update_students_updated_at ON students;

-- Step 2: Drop functions
DROP FUNCTION IF EXISTS notify_attendance_change() CASCADE;
DROP FUNCTION IF EXISTS get_attendance_stats() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Step 3: Drop views
DROP VIEW IF EXISTS attendance_stats_view CASCADE;

-- Step 4: Remove Realtime publication (if added)
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS students;

-- Step 5: Drop indexes
DROP INDEX IF EXISTS idx_students_qr_token;
DROP INDEX IF EXISTS idx_students_username;

-- Step 6: Drop RLS policies
DROP POLICY IF EXISTS "Allow read access to students" ON students;
DROP POLICY IF EXISTS "Allow update access to students" ON students;
DROP POLICY IF EXISTS "Allow insert access to students" ON students;

-- Step 7: Drop the students table (this will delete all data!)
DROP TABLE IF EXISTS students CASCADE;

-- Step 8: Verify cleanup (should return no rows)
SELECT 
  tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename = 'students';

-- Should return: (0 rows)
```

## Step 4: Disable Realtime (if enabled)

1. Go to **Database** > **Replication** in Supabase Dashboard
2. Find the `students` table
3. Toggle off replication (if it was enabled)
4. Or it will be automatically removed when the table is dropped

## Step 5: Remove Environment Variables/Secrets

If you set any secrets for edge functions:

1. Go to **Edge Functions** > **Settings**
2. Remove any secrets related to this project:
   - `GOOGLE_SHEETS_API_KEY` (if you added it)
   - Any other custom secrets

## Step 6: Verify Complete Removal

Run these queries to verify everything is removed:

```sql
-- Check for remaining tables
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename LIKE '%student%' OR tablename LIKE '%attendance%';

-- Check for remaining functions
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND (routine_name LIKE '%attendance%' OR routine_name LIKE '%student%');

-- Check for remaining triggers
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'public' 
  AND (trigger_name LIKE '%attendance%' OR trigger_name LIKE '%student%');

-- Check for remaining views
SELECT table_name 
FROM information_schema.views 
WHERE table_schema = 'public' 
  AND (table_name LIKE '%attendance%' OR table_name LIKE '%student%');
```

All queries should return **0 rows**.

## Step 7: Remove Project (Complete Deletion)

If you want to completely delete the entire Supabase project:

⚠️ **IRREVERSIBLE**: This will delete the entire project, all data, and cannot be undone.

1. Go to **Settings** > **General** in Supabase Dashboard
2. Scroll to the bottom
3. Click **Delete Project**
4. Type the project name to confirm
5. Click **Delete Project**

**Note**: This will delete:
- All databases and data
- All edge functions
- All authentication users
- All storage buckets
- Everything in the project

## Alternative: Keep Project, Remove Only This App

If you want to keep your Supabase project but only remove this QR Attendance Scanner app:

1. Follow Steps 1-5 above (skip Step 7)
2. Your Supabase project will remain active
3. You can create new tables/functions for other projects

## Quick Cleanup Script

For a quick cleanup, you can run this single SQL script:

```sql
-- Quick cleanup - removes everything related to QR Attendance Scanner
BEGIN;

-- Drop everything in one transaction
DROP TRIGGER IF EXISTS attendance_change_notifier ON students CASCADE;
DROP TRIGGER IF EXISTS update_students_updated_at ON students CASCADE;
DROP FUNCTION IF EXISTS notify_attendance_change() CASCADE;
DROP FUNCTION IF EXISTS get_attendance_stats() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP VIEW IF EXISTS attendance_stats_view CASCADE;
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS students CASCADE;

COMMIT;

-- Verify
SELECT 'Cleanup complete!' as status;
```

## Re-installation

If you want to reinstall the project later:

1. Run `supabase/migrations/001_create_students_table.sql`
2. Run `supabase/migrations/002_add_realtime_stats.sql` (optional)
3. Deploy edge functions again
4. Re-sync your Google Sheet data

## Troubleshooting

### "Cannot drop table because other objects depend on it"
- The CASCADE keyword should handle this
- If not, manually drop dependent objects first (triggers, functions, views)

### "Permission denied"
- Make sure you're using the SQL Editor with proper permissions
- You may need to use the service role key for some operations

### "Edge function still showing in dashboard"
- Wait a few minutes for the dashboard to refresh
- Try refreshing the page
- Edge functions may take time to fully delete

## Safety Checklist

Before running cleanup:

- [ ] Data backed up (if needed)
- [ ] No active users/apps depending on this data
- [ ] Edge functions are no longer in use
- [ ] You have admin access to the project
- [ ] You understand this is permanent

## After Cleanup

Once cleanup is complete:

1. ✅ All tables removed
2. ✅ All functions removed
3. ✅ All triggers removed
4. ✅ All edge functions deleted
5. ✅ All data deleted
6. ✅ Realtime disabled

Your Supabase project will be clean and ready for other projects or can be deleted entirely.

