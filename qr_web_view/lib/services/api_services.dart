import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/student_model.dart';

class ApiService {
  static const String baseUrl =
      "https://script.google.com/macros/s/AKfycbxFBF1sqfsyheJr7-DuSQJAh5ql_K1vBZbu_cMUMC0ELbJYxAAV0EmP40edWHlpmer-jw/exec";

  static Future<Student?> fetchStudent(String qrToken) async {
    try {
      final uri = Uri.parse(
        baseUrl,
      ).replace(queryParameters: {'action': 'getStudent', 'qr_token': qrToken});
      print('🔍 Requesting URL: $uri');

      final response = await http.get(uri);
      print('📥 Response Status: ${response.statusCode}');
      print('📄 Response Headers: ${response.headers}');
      print('📝 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔄 Parsed JSON: $data');
        print('✨ Success: ${data['success']}');
        print('🔢 Count: ${data['count']}');
        print('📊 Data: ${data['data']}');

        if (data['success'] == true && data['data'] != null) {
          return Student.fromJson(data['data']);
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('📚 Stack trace: $stackTrace');
    }
    return null;
  }
}
