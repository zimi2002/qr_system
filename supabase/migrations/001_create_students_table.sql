-- Create students table
CREATE TABLE IF NOT EXISTS students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL,
  name TEXT NOT NULL,
  batch TEXT,
  mentor TEXT,
  qr_token TEXT UNIQUE NOT NULL,
  sts TEXT DEFAULT 'inactive',
  in_time TIMESTAMP,
  last_scan TIMESTAMP,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on qr_token for fast lookups
CREATE INDEX IF NOT EXISTS idx_students_qr_token ON students(qr_token);

-- Create index on username for potential lookups
CREATE INDEX IF NOT EXISTS idx_students_username ON students(username);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_students_updated_at
  BEFORE UPDATE ON students
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- Create policy to allow read access (for checking student status)
CREATE POLICY "Allow read access to students"
  ON students
  FOR SELECT
  USING (true);

-- Create policy to allow update access (for activating students)
CREATE POLICY "Allow update access to students"
  ON students
  FOR UPDATE
  USING (true);

-- Create policy to allow insert access (for syncing from Google Sheets)
CREATE POLICY "Allow insert access to students"
  ON students
  FOR INSERT
  WITH CHECK (true);

