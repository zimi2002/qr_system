import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qr_attendance_scanner/models/student.dart';

class AttendanceService {
  static const String baseUrl =
      'https://script.google.com/macros/s/AKfycbzeepAa5h97Y1umew6FAdWwHQSla7kbQXkoytifMcpL3EcUnzv0Kn99AepNhhpveeipFg/exec';

  // Cache for the actual execution URL to avoid redirect delays
  static String? _cachedExecutionUrl;
  static DateTime? _cacheTimestamp;

  /// Get the actual execution URL, following redirects only once
  static Future<String> _getExecutionUrl() async {
    // Check if we have a valid cached URL
    if (_cachedExecutionUrl != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!).inHours < 1) {
      print('Using cached execution URL: $_cachedExecutionUrl');
      return _cachedExecutionUrl!;
    }

    try {
      print('Resolving redirect URL...');
      // Follow redirects to get the actual execution URL
      final request = http.Request('GET', Uri.parse(baseUrl));
      final streamedResponse = await request.send();

      // Get the final URL after redirects
      final finalUrl = streamedResponse.request!.url.toString();

      // Cache the result
      _cachedExecutionUrl = finalUrl;
      _cacheTimestamp = DateTime.now();

      print('Cached new execution URL: $finalUrl');
      return finalUrl;
    } catch (e) {
      print('Failed to resolve redirect URL, using original: $e');
      // Fallback to original URL if redirect resolution fails
      return baseUrl;
    }
  }

  /// Make API request using GET with query parameters (better for Google Apps Script)
  static Future<Map<String, dynamic>> _makeRequest(
    Map<String, String> params,
  ) async {
    try {
      // Get the optimized execution URL (cached or resolved)
      final executionUrl = await _getExecutionUrl();
      final uri = Uri.parse(executionUrl).replace(queryParameters: params);
      print('Request URL: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode != 200) {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }

      final data = jsonDecode(response.body);
      if (data == null || data['success'] != true || data['data'] == null) {
        return {
          'success': false,
          'error': data['error'] ?? 'QR token not found',
        };
      }

      return {'success': true, 'data': data['data']};
    } catch (e) {
      print('Request Error: $e');
      return {'success': false, 'error': 'Network or parsing error: $e'};
    }
  }

  /// Check student status by QR token
  static Future<Map<String, dynamic>> checkStudent(String qrToken) async {
    return _makeRequest({'action': 'getStudent', 'qr_token': qrToken});
  }

  /// Activate student by QR token (marks sts=active, updates in_time & last_scan)
  static Future<Map<String, dynamic>> activateStudent(String qrToken) async {
    return _makeRequest({'action': 'activate', 'qr_token': qrToken});
  }

  /// Full attendance flow
  /// Logic:
  /// - First scan (sts=inactive): Activate sets in_time, changes sts to active → SUCCESS screen
  /// - Subsequent scans (sts=active): Activate only updates last_scan → DUPLICATE screen
 static Future<Map<String, dynamic>> processAttendance(String qrToken) async {
  try {
    print('\n╔══════════════════════════════════════╗');
    print('║  PROCESS ATTENDANCE STARTED          ║');
    print('╚══════════════════════════════════════╝');
    print('QR Token: $qrToken\n');

    // 🔹 Step 1: Call backend activate endpoint
    final activateResponse = await activateStudent(qrToken);
    print('activate response: $activateResponse\n');

    if (!activateResponse['success']) {
      return {
        'status': 'error',
        'error': activateResponse['error'] ?? 'Failed to activate student',
      };
    }

    final student = Student.fromJson(activateResponse['data']);
    final isDuplicate = activateResponse['data']['is_duplicate_scan'] == true;

    // 🔹 Step 2: Decide based on backend flag
    if (isDuplicate) {
      print('⚠️ Duplicate scan detected by backend.');
      return {
        'status': 'duplicate',
        'student': student,
        'message': 'Student already scanned recently',
      };
    }

    // 🔹 Step 3: Success case
    print('✅ Attendance marked successfully.');
    return {
      'status': 'success',
      'student': student,
      'message': 'Attendance marked successfully',
    };
  } catch (e) {
    print('❌ Error during processAttendance: $e');
    return {'status': 'error', 'error': 'Unexpected error: $e'};
  }
}

}
