import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_attendance_scanner/models/student.dart';
import 'package:qr_attendance_scanner/config/supabase_config.dart';
import 'package:logger/logger.dart';

class AttendanceService {
  // Logger instance for structured logging
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
  );

  // Persistent HTTP client for connection reuse
  static final http.Client _httpClient = http.Client();

  // Cache for recent requests to prevent duplicates
  static final Map<String, Map<String, dynamic>> _requestCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(seconds: 30);

  // Get Supabase client instance
  static SupabaseClient get _supabase => Supabase.instance.client;

  // Get the edge function URL for attendance operations
  static String get _attendanceFunctionUrl {
    final supabaseUrl = SupabaseConfig.supabaseUrl;
    return '$supabaseUrl/functions/v1/attendance-check';
  }

  /// Clear expired cache entries
  static void _cleanCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheDuration)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _requestCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Get cache key for request parameters
  static String _getCacheKey(Map<String, String> params) {
    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return jsonEncode(sortedParams);
  }

  /// Make API request to Supabase Edge Function with optimizations
  static Future<Map<String, dynamic>> _makeRequest(
    Map<String, String> params, {
    int maxRetries = 1, // Reduced retries for faster failure
    Duration timeout = const Duration(seconds: 8), // Reduced timeout
  }) async {
    final requestStopwatch = Stopwatch()..start();

    // Check cache first for duplicate scan prevention
    _cleanCache();
    final cacheKey = _getCacheKey(params);
    if (_requestCache.containsKey(cacheKey)) {
      _logger.d('⚡ Returning cached response for ${params['qr_token']}');
      final cachedResult = Map<String, dynamic>.from(_requestCache[cacheKey]!);
      cachedResult['is_duplicate_scan'] = true;
      return cachedResult;
    }

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          _logger.w('🔄 Retry attempt $attempt/$maxRetries');
          // Shorter delay before retry
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }

        final networkStopwatch = Stopwatch()..start();

        // Pre-build headers for efficiency
        final session = _supabase.auth.currentSession;
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'apikey': SupabaseConfig.supabaseAnonKey,
          'Authorization': session != null
              ? 'Bearer ${session.accessToken}'
              : 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        };

        final requestBody = jsonEncode(params);

        _logger.d('📡 Request: ${params['action']} for ${params['qr_token']}');

        // Use persistent HTTP client for connection reuse
        final response = await _httpClient
            .post(
              Uri.parse(_attendanceFunctionUrl),
              headers: headers,
              body: requestBody,
            )
            .timeout(timeout);

        networkStopwatch.stop();
        requestStopwatch.stop();

        _logger.d(
          '⚡ Network: ${networkStopwatch.elapsedMilliseconds}ms, '
          'Total: ${requestStopwatch.elapsedMilliseconds}ms (attempt ${attempt + 1})',
        );

        if (response.statusCode != 200) {
          _logger.w('❌ HTTP ${response.statusCode}: ${response.body}');

          if (attempt < maxRetries && response.statusCode >= 500) {
            continue; // Retry server errors only
          }

          // Parse error message efficiently
          try {
            final errorData = jsonDecode(response.body);
            return {
              'success': false,
              'error':
                  errorData['error'] ?? 'Server error: ${response.statusCode}',
            };
          } catch (e) {
            return {
              'success': false,
              'error': 'Server error: ${response.statusCode}',
            };
          }
        }

        final data = jsonDecode(response.body);
        if (data?['success'] != true) {
          return {
            'success': false,
            'error': data?['error'] ?? 'Request failed',
          };
        }

        // Cache successful responses
        final result = {
          'success': true,
          'data': data['data'],
          'is_duplicate_scan': data['is_duplicate_scan'] ?? false,
          if (data['previous_scan_time'] != null)
            'previous_scan_time': data['previous_scan_time'],
        };

        _requestCache[cacheKey] = result;
        _cacheTimestamps[cacheKey] = DateTime.now();

        _logger.i('✅ ${params['action']} successful for ${params['qr_token']}');
        return result;
      } catch (e) {
        _logger.e('❌ Request error (attempt ${attempt + 1}): $e');

        if (attempt == maxRetries) {
          return {
            'success': false,
            'error': 'Network timeout. Check connection and try again.',
          };
        }
      }
    }

    return {'success': false, 'error': 'Max retries exceeded. Try again.'};
  }

  /// Check student status by QR token
  static Future<Map<String, dynamic>> checkStudent(String qrToken) async {
    return _makeRequest({'action': 'getStudent', 'qr_token': qrToken});
  }

  /// Activate student by QR token (marks sts=active, updates in_time & last_scan)
  static Future<Map<String, dynamic>> activateStudent(String qrToken) async {
    return _makeRequest({'action': 'activate', 'qr_token': qrToken});
  }

  /// Full attendance flow with optimized performance
  /// Logic:
  /// - First scan (sts=inactive): Activate sets in_time, changes sts to active → SUCCESS screen
  /// - Subsequent scans (sts=active): Activate only updates last_scan → DUPLICATE screen
  /// - Cached scans: Return cached response immediately → DUPLICATE screen
  static Future<Map<String, dynamic>> processAttendance(String qrToken) async {
    try {
      _logger.i('🎯 Processing attendance for QR: $qrToken');

      // 🔹 Step 1: Call backend activate endpoint (with caching)
      final activateResponse = await activateStudent(qrToken);

      if (!activateResponse['success']) {
        _logger.w('❌ Activation failed: ${activateResponse['error']}');
        return {
          'status': 'error',
          'error': activateResponse['error'] ?? 'Failed to activate student',
        };
      }

      final student = Student.fromJson(activateResponse['data']);
      final isDuplicate = activateResponse['is_duplicate_scan'] == true;
      final previousScanTimeRaw = activateResponse['previous_scan_time'];

      // Format previous scan time for display (if available)
      String? formattedPreviousScanTime;
      if (previousScanTimeRaw != null && previousScanTimeRaw is String) {
        try {
          final dateTime = DateTime.parse(previousScanTimeRaw);
          formattedPreviousScanTime =
              '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
              '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
        } catch (e) {
          // If parsing fails, use the raw value
          formattedPreviousScanTime = previousScanTimeRaw.toString();
        }
      }

      // 🔹 Step 2: Decide based on duplicate flag
      if (isDuplicate) {
        _logger.d('⚠️ Duplicate scan detected for ${student.name}');
        return {
          'status': 'duplicate',
          'student': student,
          'message': 'Student already scanned recently',
          if (formattedPreviousScanTime != null)
            'previous_scan_time': formattedPreviousScanTime,
        };
      }

      // 🔹 Step 3: Success case
      _logger.i('✅ Attendance marked for ${student.name} (${student.batch})');
      return {
        'status': 'success',
        'student': student,
        'message': 'Attendance marked successfully',
      };
    } catch (e) {
      _logger.e('💥 Error during processAttendance: $e');
      return {'status': 'error', 'error': 'Unexpected error: $e'};
    }
  }

  /// Clean up resources when service is no longer needed
  static void dispose() {
    _httpClient.close();
    _requestCache.clear();
    _cacheTimestamps.clear();
  }
}
