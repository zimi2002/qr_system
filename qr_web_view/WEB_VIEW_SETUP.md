# QR Web View - Supabase Integration Guide

This guide explains how to set up and use the Supabase integration in the QR Web View project.

## Overview

The QR Web View now includes:
- **Real-time Attendance Statistics** page at `/stats`
- Supabase integration for live data updates
- Automatic stats refresh when attendance changes

## Setup

### 1. Install Dependencies

```bash
cd qr_web_view
flutter pub get
```

### 2. Configure Supabase

1. Open `lib/config/supabase_config.dart`
2. Replace `YOUR_SUPABASE_URL` with your Supabase project URL
3. Replace `YOUR_SUPABASE_ANON_KEY` with your anon/public key
4. Get these from: Supabase Dashboard > Settings > API

### 3. Enable Realtime (Required for Live Updates)

1. Go to Supabase Dashboard > Database > Replication
2. Enable replication for the `students` table
3. Run the migration: `supabase/migrations/002_add_realtime_stats.sql` (if not already done)

## Usage

### Accessing the Stats Page

Navigate to: `https://your-domain.com/stats`

The stats page will automatically:
- Load initial statistics
- Subscribe to real-time updates
- Refresh when students scan QR codes

### Features

- **Live Updates**: Stats update automatically when attendance changes
- **Overview Cards**: Total, Attended, Remaining, Percentage, Last 24h
- **Batch Breakdown**: Detailed statistics by batch with progress bars
- **Responsive Design**: Works on desktop, tablet, and mobile
- **Manual Refresh**: Refresh button in the app bar

### Routes

- `/` - Student QR view page (existing)
- `/stats` - Attendance statistics page (new)

## Real-time Updates

The stats page uses Supabase Realtime to automatically update when:
- A student scans their QR code (attendance marked)
- A new student is added to the database
- Student attendance status changes

You'll see a green "Live" indicator in the app bar when real-time updates are active.

## Troubleshooting

### Stats not loading
- Verify Supabase credentials in `supabase_config.dart`
- Check that the database function `get_attendance_stats()` exists
- Ensure RLS policies allow read access

### Real-time updates not working
- Verify Realtime is enabled for `students` table
- Check browser console for WebSocket connection errors
- Ensure the migration `002_add_realtime_stats.sql` has been run

### "RPC failed" errors
- The service will automatically fallback to edge function
- Verify edge function `attendance-stats-realtime` is deployed
- Check Supabase Dashboard > Edge Functions

## Development

### Running Locally

```bash
flutter run -d chrome
# or
flutter run -d web-server
```

### Building for Production

```bash
flutter build web
```

The built files will be in `build/web/`

## Integration with Existing Code

The Supabase integration doesn't affect the existing student QR view page. Both features work independently:
- Student page (`/`) - Shows individual student info from QR token
- Stats page (`/stats`) - Shows overall attendance statistics

Both can use the same Supabase instance and credentials.

