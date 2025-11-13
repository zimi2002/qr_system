import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qr_attendance_scanner/models/student.dart';

class AttendanceService {
  static const String baseUrl =
      'https://script.google.com/macros/s/AKfycbzeepAa5h97Y1umew6FAdWwHQSla7kbQXkoytifMcpL3EcUnzv0Kn99AepNhhpveeipFg/exec';

  /// Make API request using GET with query parameters (better for Google Apps Script)
  static Future<Map<String, dynamic>> _makeRequest(
    Map<String, String> params,
  ) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: params);
      print('Request URL: $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

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
