-- ============================================
-- COMPLETE CLEANUP SCRIPT
-- Use this to completely remove the QR Attendance Scanner from Supabase
-- 
-- WARNING: This will permanently delete all data!
-- Make sure you have backups before running this.
-- ============================================

BEGIN;

-- Step 1: Drop triggers
DROP TRIGGER IF EXISTS attendance_change_notifier ON students CASCADE;
DROP TRIGGER IF EXISTS update_students_updated_at ON students CASCADE;

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

COMMIT;

-- Verification queries (run separately to verify cleanup)
-- These should return 0 rows after cleanup:

-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename = 'students';
-- SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name LIKE '%attendance%';
-- SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema = 'public' AND trigger_name LIKE '%attendance%';

