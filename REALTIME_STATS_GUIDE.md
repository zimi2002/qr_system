# Real-time Attendance Stats Guide

This guide shows you how to get real-time updates for attendance statistics using Supabase Realtime.

## Overview

There are two ways to get real-time attendance stats:

1. **Database Function + Realtime Subscription** (Recommended)
   - Subscribe to PostgreSQL notifications that fire when attendance changes
   - Automatically receive updated stats whenever a student scans their QR code

2. **Polling with Edge Function**
   - Call the edge function periodically to get updated stats
   - Simpler but less efficient

## Method 1: Real-time Subscription (Recommended)

### Setup

1. Run the migration to enable realtime:
   ```sql
   -- This is in supabase/migrations/002_add_realtime_stats.sql
   -- Run it in Supabase SQL Editor
   ```

2. Enable Realtime in Supabase Dashboard:
   - Go to Database > Replication
   - Enable replication for the `students` table

### Quick Start (Using Pre-built Service)

We've created a ready-to-use service: `lib/services/realtime_stats_service.dart`

```dart
import 'package:qr_attendance_scanner/services/realtime_stats_service.dart';

final statsService = RealtimeStatsService();

// Subscribe to real-time updates
statsService.subscribeToStats(
  onUpdate: (stats) {
    print('Total: ${stats['total']}, Attended: ${stats['attended']}');
    // Update your UI
    setState(() {
      totalStudents = stats['total'];
      attendedStudents = stats['attended'];
      remainingStudents = stats['remaining'];
    });
  },
  onError: (error) {
    print('Error: $error');
  },
);

// Get initial stats
final initialStats = await statsService.getCurrentStats();

// Don't forget to unsubscribe when done
// statsService.unsubscribe();
```

### Custom Client Implementation (Flutter/Dart)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeStatsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  
  // Subscribe to real-time stats updates
  void subscribeToStats({
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Object) onError,
  }) {
    // Listen to PostgreSQL notifications
    _channel = _supabase.channel('attendance_stats')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'students',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.update,
          columns: ['sts', 'in_time', 'last_scan'],
        ),
        callback: (payload) async {
          // When attendance changes, fetch updated stats
          final stats = await _getStats();
          onUpdate(stats);
        },
      )
      .subscribe();
  }
  
  // Alternative: Listen to custom notifications
  void subscribeToStatsViaNotify({
    required Function(Map<String, dynamic>) onUpdate,
    required Function(Object) onError,
  }) {
    _channel = _supabase.channel('attendance_stats_notify')
      .on('postgres_changes', {
        'event': '*',
        'schema': 'public',
        'table': 'students',
      }, (payload, [ref]) async {
        // Fetch updated stats when notified
        final stats = await _getStats();
        onUpdate(stats);
      })
      .subscribe();
  }
  
  // Get current stats
  Future<Map<String, dynamic>> _getStats() async {
    final response = await _supabase.rpc('get_attendance_stats');
    return response as Map<String, dynamic>;
  }
  
  // Unsubscribe
  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
```

### Usage Example

```dart
final statsService = RealtimeStatsService();

statsService.subscribeToStats(
  onUpdate: (stats) {
    print('Stats updated: ${stats['attended']}/${stats['total']}');
    // Update your UI here
    setState(() {
      totalStudents = stats['total'];
      attendedStudents = stats['attended'];
      remainingStudents = stats['remaining'];
    });
  },
  onError: (error) {
    print('Error: $error');
  },
);

// Don't forget to unsubscribe when done
// statsService.unsubscribe();
```

## Method 2: WebSocket Connection (Advanced)

For a more direct approach, you can use Supabase Realtime WebSocket:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeStatsWebSocket {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  
  void connect({
    required Function(Map<String, dynamic>) onStatsUpdate,
  }) {
    _channel = _supabase.channel('attendance_stats_channel')
      .onBroadcast(
        event: 'stats_update',
        callback: (payload) {
          onStatsUpdate(payload['stats'] as Map<String, dynamic>);
        },
      )
      .subscribe();
  }
  
  void disconnect() {
    _channel?.unsubscribe();
  }
}
```

## Method 3: Polling (Simple but Less Efficient)

If you prefer a simpler approach without WebSockets:

```dart
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StatsPoller {
  Timer? _timer;
  final String supabaseUrl;
  final String anonKey;
  
  StatsPoller(this.supabaseUrl, this.anonKey);
  
  void startPolling({
    required Function(Map<String, dynamic>) onUpdate,
    Duration interval = const Duration(seconds: 5),
  }) {
    _timer = Timer.periodic(interval, (timer) async {
      try {
        final response = await http.post(
          Uri.parse('$supabaseUrl/functions/v1/attendance-stats-realtime'),
          headers: {
            'Authorization': 'Bearer $anonKey',
            'Content-Type': 'application/json',
          },
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            onUpdate(data['data']);
          }
        }
      } catch (e) {
        print('Error polling stats: $e');
      }
    });
  }
  
  void stopPolling() {
    _timer?.cancel();
  }
}

// Usage:
final poller = StatsPoller(supabaseUrl, anonKey);
poller.startPolling(
  onUpdate: (stats) {
    print('Stats: ${stats['attended']}/${stats['total']}');
  },
  interval: Duration(seconds: 5), // Poll every 5 seconds
);
```

## Method 4: Using the Database Function Directly

You can also call the database function directly and subscribe to table changes:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class DirectRealtimeStats {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  
  void subscribe({
    required Function(Map<String, dynamic>) onUpdate,
  }) {
    // Subscribe to students table changes
    _channel = _supabase
      .channel('students_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'students',
        callback: (payload) async {
          // When any student record is updated, fetch fresh stats
          final response = await _supabase.rpc('get_attendance_stats');
          onUpdate(response as Map<String, dynamic>);
        },
      )
      .subscribe();
  }
  
  void unsubscribe() {
    _channel?.unsubscribe();
  }
}
```

## Recommended Approach

For the best performance and real-time updates, use **Method 1** or **Method 4**:

1. They automatically update when attendance changes
2. No unnecessary polling
3. Efficient use of resources
4. Low latency updates

## Testing Real-time Updates

1. Open your app and subscribe to stats
2. In another device/app, scan a QR code to mark attendance
3. Watch the stats update automatically in real-time!

## Troubleshooting

### Stats not updating
- Verify Realtime is enabled for the `students` table in Supabase Dashboard
- Check that the trigger is created: `attendance_change_notifier`
- Ensure you're subscribed to the correct channel

### Connection issues
- Check your Supabase URL and keys
- Verify network connectivity
- Check Supabase Dashboard > Logs for errors

### Performance
- If you have many concurrent users, consider rate limiting
- The database function is optimized with indexes
- Consider caching stats if updates are too frequent

