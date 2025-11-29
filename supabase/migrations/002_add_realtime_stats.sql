-- Enable Realtime for students table
ALTER PUBLICATION supabase_realtime ADD TABLE students;

-- Create a function to get attendance stats
CREATE OR REPLACE FUNCTION get_attendance_stats()
RETURNS JSON AS $$
DECLARE
  total_count INTEGER;
  attended_count INTEGER;
  remaining_count INTEGER;
  recent_24h_count INTEGER;
  attendance_percentage NUMERIC;
  batch_stats JSON;
  result JSON;
BEGIN
  -- Get total count
  SELECT COUNT(*) INTO total_count FROM students;

  -- Get attended count (sts='active' or has in_time)
  SELECT COUNT(*) INTO attended_count 
  FROM students 
  WHERE sts = 'active' OR in_time IS NOT NULL;

  -- Calculate remaining
  remaining_count := total_count - attended_count;

  -- Get recent 24h count
  SELECT COUNT(*) INTO recent_24h_count 
  FROM students 
  WHERE last_scan >= NOW() - INTERVAL '24 hours';

  -- Calculate attendance percentage
  IF total_count > 0 THEN
    attendance_percentage := ROUND((attended_count::NUMERIC / total_count::NUMERIC * 100)::NUMERIC, 2);
  ELSE
    attendance_percentage := 0;
  END IF;

  -- Get breakdown by batch
  SELECT json_object_agg(
    COALESCE(batch, 'Unknown'),
    json_build_object(
      'total', batch_total,
      'attended', batch_attended,
      'remaining', batch_total - batch_attended
    )
  ) INTO batch_stats
  FROM (
    SELECT 
      batch,
      COUNT(*) as batch_total,
      COUNT(*) FILTER (WHERE sts = 'active' OR in_time IS NOT NULL) as batch_attended
    FROM students
    GROUP BY batch
  ) batch_data;

  -- Build result JSON
  result := json_build_object(
    'total', total_count,
    'attended', attended_count,
    'remaining', remaining_count,
    'recent_24h', recent_24h_count,
    'attendance_percentage', attendance_percentage,
    'by_batch', COALESCE(batch_stats, '{}'::json),
    'timestamp', NOW()
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

-- Create a view for realtime stats (can be subscribed to)
CREATE OR REPLACE VIEW attendance_stats_view AS
SELECT 
  get_attendance_stats() as stats,
  NOW() as updated_at;

-- Enable Realtime for the view (optional, for direct subscription)
-- Note: Views don't support realtime directly, but we can use the function

-- Create a trigger function to notify on attendance changes
CREATE OR REPLACE FUNCTION notify_attendance_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Notify via pg_notify (Supabase Realtime listens to these)
  PERFORM pg_notify(
    'attendance_stats_update',
    json_build_object(
      'stats', get_attendance_stats(),
      'changed_student', json_build_object(
        'qr_token', COALESCE(NEW.qr_token, OLD.qr_token),
        'username', COALESCE(NEW.username, OLD.username),
        'name', COALESCE(NEW.name, OLD.name)
      )
    )::text
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on students table
CREATE TRIGGER attendance_change_notifier
  AFTER INSERT OR UPDATE OF sts, in_time, last_scan ON students
  FOR EACH ROW
  EXECUTE FUNCTION notify_attendance_change();


