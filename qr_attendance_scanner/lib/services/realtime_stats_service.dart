import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for getting real-time attendance statistics
class RealtimeStatsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  /// Subscribe to real-time stats updates
  /// Stats will automatically update whenever a student's attendance changes
  void subscribeToStats({
    required Function(Map<String, dynamic>) onUpdate,
    Function(Object)? onError,
  }) {
    // Subscribe to changes on the students table
    _channel = _supabase
        .channel('attendance_stats_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'students',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sts',
            value: 'active',
          ),
          callback: (payload) async {
            try {
              // When attendance changes, fetch updated stats
              final stats = await getCurrentStats();
              onUpdate(stats);
            } catch (e) {
              onError?.call(e);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'students',
          callback: (payload) async {
            try {
              // When new student is added, fetch updated stats
              final stats = await getCurrentStats();
              onUpdate(stats);
            } catch (e) {
              onError?.call(e);
            }
          },
        )
        .subscribe();
  }

  /// Get current attendance statistics
  /// Uses the database function for optimal performance
  Future<Map<String, dynamic>> getCurrentStats() async {
    try {
      // Call the database function
      final response = await _supabase.rpc('get_attendance_stats');
      return response as Map<String, dynamic>;
    } catch (e) {
      // Fallback to edge function if RPC fails
      print('RPC failed, using edge function: $e');
      return await _getStatsViaEdgeFunction();
    }
  }

  /// Fallback: Get stats via edge function
  Future<Map<String, dynamic>> _getStatsViaEdgeFunction() async {
    final response = await _supabase.functions.invoke(
      'attendance-stats-realtime',
    );

    if (response.data != null && response.data['success'] == true) {
      return response.data['data'] as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to get stats: ${response.data?['error'] ?? 'Unknown error'}',
    );
  }

  /// Unsubscribe from real-time updates
  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  /// Dispose resources
  void dispose() {
    unsubscribe();
  }
}
