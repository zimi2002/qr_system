import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student_model.dart';

class ApiService {
  static const String baseUrl =
      "https://script.google.com/macros/s/AKfycbxFBF1sqfsyheJr7-DuSQJAh5ql_K1vBZbu_cMUMC0ELbJYxAAV0EmP40edWHlpmer-jw/exec";
  
  // Cache TTL: 1 hour in milliseconds
  static const int _cacheTTL = 60 * 60 * 1000;
  static const String _cachePrefix = 'student_cache_';
  static const String _cacheTimePrefix = 'student_cache_time_';
  
  // Request timeout: 10 seconds
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// Fetch student data with caching support
  /// Returns cached data immediately if available and not expired
  /// Fetches fresh data in background and updates cache
  static Future<Student?> fetchStudent(String qrToken, {bool useCache = true}) async {
    // Try to get cached data first
    if (useCache) {
      final cachedStudent = await _getCachedStudent(qrToken);
      if (cachedStudent != null) {
        debugPrint('✅ Using cached student data for token: $qrToken');
        // Fetch fresh data in background without blocking
        _fetchAndCacheStudent(qrToken);
        return cachedStudent;
      }
    }

    // No cache available, fetch from API
    return await _fetchAndCacheStudent(qrToken);
  }

  /// Get cached student data if available and not expired
  static Future<Student?> _getCachedStudent(String qrToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$qrToken';
      final timeKey = '$_cacheTimePrefix$qrToken';

      final cachedData = prefs.getString(cacheKey);
      final cachedTime = prefs.getInt(timeKey);

      if (cachedData != null && cachedTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final age = now - cachedTime;

        // Check if cache is still valid
        if (age < _cacheTTL) {
          final jsonData = jsonDecode(cachedData);
          return Student.fromJson(jsonData);
        } else {
          // Cache expired, remove it
          await prefs.remove(cacheKey);
          await prefs.remove(timeKey);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error reading cache: $e');
    }
    return null;
  }

  /// Fetch student from API and cache the result
  static Future<Student?> _fetchAndCacheStudent(String qrToken) async {
    try {
      final uri = Uri.parse(
        baseUrl,
      ).replace(queryParameters: {'action': 'getStudent', 'qr_token': qrToken});
      debugPrint('🔍 Requesting URL: $uri');

      final response = await http
          .get(uri)
          .timeout(_requestTimeout, onTimeout: () {
        throw Exception('Request timeout after ${_requestTimeout.inSeconds} seconds');
      });

      debugPrint('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🔄 Parsed JSON: $data');
        debugPrint('✨ Success: ${data['success']}');

        if (data['success'] == true && data['data'] != null) {
          final student = Student.fromJson(data['data']);
          
          // Cache the result
          await _cacheStudent(qrToken, data['data']);
          
          return student;
        }
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error: $e');
      if (e.toString().contains('timeout')) {
        debugPrint('⏱️ Request timed out');
      } else {
        debugPrint('📚 Stack trace: $stackTrace');
      }
    }
    return null;
  }

  /// Cache student data with timestamp
  static Future<void> _cacheStudent(String qrToken, Map<String, dynamic> studentData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$qrToken';
      final timeKey = '$_cacheTimePrefix$qrToken';

      await prefs.setString(cacheKey, jsonEncode(studentData));
      await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('💾 Cached student data for token: $qrToken');
    } catch (e) {
      debugPrint('⚠️ Error caching student data: $e');
    }
  }

  /// Clear cache for a specific token
  static Future<void> clearCache(String qrToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cachePrefix$qrToken');
      await prefs.remove('$_cacheTimePrefix$qrToken');
      debugPrint('🗑️ Cleared cache for token: $qrToken');
    } catch (e) {
      debugPrint('⚠️ Error clearing cache: $e');
    }
  }

  /// Clear all cached student data
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) || key.startsWith(_cacheTimePrefix)) {
          await prefs.remove(key);
        }
      }
      debugPrint('🗑️ Cleared all student cache');
    } catch (e) {
      debugPrint('⚠️ Error clearing all cache: $e');
    }
  }
}
