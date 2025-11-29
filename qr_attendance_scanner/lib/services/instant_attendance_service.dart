import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import 'package:qr_attendance_scanner/models/student.dart';
import 'package:qr_attendance_scanner/services/local_database_service.dart';
import 'package:qr_attendance_scanner/services/attendance_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ultra-fast attendance service with instant responses
///
/// Strategy:
/// 1. Check local cache first (instant response <50ms)
/// 2. Return immediate feedback to user
/// 3. Sync with backend in background
/// 4. Handle offline scenarios gracefully
class InstantAttendanceService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, colors: true, printEmojis: true),
  );

  // Connection state
  static ConnectivityResult? _lastConnectivityState;
  static StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Background sync timer
  static Timer? _backgroundSyncTimer;

  // Recently processed QR codes (in-memory cache for ultra-fast duplicate detection)
  static final Set<String> _recentScans = <String>{};
  static final Map<String, DateTime> _scanTimestamps = <String, DateTime>{};
  static const Duration _duplicateThreshold = Duration(seconds: 30);

  /// Initialize the service
  static Future<void> initialize() async {
    _logger.i('🚀 Initializing InstantAttendanceService...');

    // Initialize connectivity monitoring
    await _initializeConnectivity();

    // Start background sync
    _startBackgroundSync();

    // Pre-warm connections
    await _preWarmConnections();

    // Load frequent students
    await _loadFrequentStudents();

    _logger.i('✅ InstantAttendanceService initialized');
  }

  /// Process attendance with instant response
  static Future<Map<String, dynamic>> processAttendanceInstant(
    String qrToken,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.d('⚡ Processing QR: $qrToken');

      // Step 1: Instant duplicate check (in-memory)
      if (_isRecentDuplicate(qrToken)) {
        _logger.d(
          '🔄 In-memory duplicate detected in ${stopwatch.elapsedMilliseconds}ms',
        );
        // Try to get student from cache for display
        final cachedStudent = await LocalDatabaseService.getCachedStudent(
          qrToken,
        );
        return _createDuplicateResponse(qrToken, cachedStudent);
      }

      // Step 2: Check local database cache (very fast)
      final cachedStudent = await LocalDatabaseService.getCachedStudent(
        qrToken,
      );

      if (cachedStudent != null) {
        // Check if recently scanned in database
        final wasRecentlyScanned =
            await LocalDatabaseService.wasRecentlyScanned(qrToken);

        if (wasRecentlyScanned) {
          _logger.d(
            '💾 Database duplicate detected in ${stopwatch.elapsedMilliseconds}ms',
          );
          return _createDuplicateResponse(qrToken, cachedStudent);
        }

        // Record the scan locally immediately
        _recordRecentScan(qrToken);
        await LocalDatabaseService.recordAttendanceScan(qrToken, 'success');
        await LocalDatabaseService.updateStudentStatus(qrToken, 'active');

        // Add to background sync queue
        await LocalDatabaseService.addToSyncQueue(
          qrToken,
          'activate',
          priority: 1,
        );

        _logger.i(
          '⚡ Instant success response in ${stopwatch.elapsedMilliseconds}ms',
        );
        return _createSuccessResponse(cachedStudent);
      }

      // Step 3: Not in cache - check if online
      final isOnline = await _isOnline();

      if (isOnline) {
        // Try to get from backend immediately
        _logger.d('🌐 Fetching from backend for unknown QR');
        final result = await AttendanceService.processAttendance(qrToken);

        if (result['status'] == 'success' || result['status'] == 'duplicate') {
          final student = result['student'] as Student;

          // Cache the student for future instant access
          await LocalDatabaseService.cacheStudent(student);

          if (result['status'] == 'success') {
            await LocalDatabaseService.recordAttendanceScan(
              qrToken,
              'success',
              synced: true,
            );
            _recordRecentScan(qrToken);
          }

          _logger.i(
            '🌐 Backend response in ${stopwatch.elapsedMilliseconds}ms',
          );
          return result;
        }
      }

      // Step 4: Offline or unknown QR - queue for later processing
      _logger.w('📱 Offline mode - queuing for later sync');
      await LocalDatabaseService.addToSyncQueue(
        qrToken,
        'validate',
        priority: 1,
      );

      return {
        'status': 'queued',
        'message': 'QR code queued for processing when online',
        'offline': !isOnline,
        'processing_time': stopwatch.elapsedMilliseconds,
      };
    } catch (e) {
      _logger.e('💥 Error in instant processing: $e');
      return {
        'status': 'error',
        'error': 'Processing error: $e',
        'processing_time': stopwatch.elapsedMilliseconds,
      };
    } finally {
      stopwatch.stop();
    }
  }

  /// Check if QR was recently scanned (in-memory cache)
  static bool _isRecentDuplicate(String qrToken) {
    final now = DateTime.now();

    // Clean old entries
    _scanTimestamps.removeWhere(
      (key, value) => now.difference(value) > _duplicateThreshold,
    );
    _recentScans.removeWhere((key) => !_scanTimestamps.containsKey(key));

    return _recentScans.contains(qrToken);
  }

  /// Record recent scan in memory
  static void _recordRecentScan(String qrToken) {
    _recentScans.add(qrToken);
    _scanTimestamps[qrToken] = DateTime.now();
  }

  /// Create duplicate response
  static Map<String, dynamic> _createDuplicateResponse(
    String qrToken, [
    Student? student,
  ]) {
    return {
      'status': 'duplicate',
      'student': student,
      'message': 'Student already scanned recently',
      'qr_token': qrToken,
      'processing_time': 0, // Instant
    };
  }

  /// Create success response
  static Map<String, dynamic> _createSuccessResponse(Student student) {
    return {
      'status': 'success',
      'student': student,
      'message': 'Attendance marked successfully',
      'processing_time': 0, // Near-instant
    };
  }

  /// Initialize connectivity monitoring
  static Future<void> _initializeConnectivity() async {
    final connectivity = Connectivity();
    _lastConnectivityState = await connectivity.checkConnectivity();

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      _logger.d('📡 Connectivity changed: $result');
      _lastConnectivityState = result;

      // Trigger sync when coming back online
      if (result != ConnectivityResult.none) {
        _triggerImmediateSync();
      }
    });
  }

  /// Check if device is online
  static Future<bool> _isOnline() async {
    if (_lastConnectivityState == null) {
      final connectivity = Connectivity();
      _lastConnectivityState = await connectivity.checkConnectivity();
    }
    return _lastConnectivityState != ConnectivityResult.none;
  }

  /// Start background sync timer
  static void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(
      Duration(seconds: 10), // Sync every 10 seconds when online
      (timer) => _performBackgroundSync(),
    );
  }

  /// Perform background synchronization
  static Future<void> _performBackgroundSync() async {
    if (!await _isOnline()) return;

    try {
      final pendingOps = await LocalDatabaseService.getPendingSyncOperations();

      if (pendingOps.isEmpty) return;

      _logger.d('🔄 Syncing ${pendingOps.length} pending operations');

      for (final op in pendingOps) {
        try {
          await _processSyncOperation(op);
        } catch (e) {
          _logger.w('⚠️ Failed to sync operation ${op['id']}: $e');

          // Increment retry count
          final retryCount = (op['retry_count'] as int) + 1;
          if (retryCount < 3) {
            await LocalDatabaseService.updateSyncRetryCount(
              op['id'],
              retryCount,
            );
          } else {
            _logger.e(
              '❌ Max retries reached for operation ${op['id']}, removing',
            );
            await LocalDatabaseService.removeSyncOperation(op['id']);
          }
        }
      }
    } catch (e) {
      _logger.e('💥 Error in background sync: $e');
    }
  }

  /// Process individual sync operation
  static Future<void> _processSyncOperation(Map<String, dynamic> op) async {
    final qrToken = op['qr_token'] as String;
    final action = op['action'] as String;

    switch (action) {
      case 'activate':
        final result = await AttendanceService.activateStudent(qrToken);
        if (result['success'] == true) {
          await LocalDatabaseService.removeSyncOperation(op['id']);
          _logger.d('✅ Synced activation for $qrToken');
        } else {
          throw Exception('Backend activation failed: ${result['error']}');
        }
        break;

      case 'validate':
        final result = await AttendanceService.checkStudent(qrToken);
        if (result['success'] == true) {
          final student = Student.fromJson(result['data']);
          await LocalDatabaseService.cacheStudent(student);
          await LocalDatabaseService.removeSyncOperation(op['id']);
          _logger.d('✅ Validated and cached $qrToken');
        } else {
          throw Exception('Student validation failed: ${result['error']}');
        }
        break;

      case 'preload':
        final result = await AttendanceService.checkStudent(qrToken);
        if (result['success'] == true) {
          final student = Student.fromJson(result['data']);
          await LocalDatabaseService.cacheStudent(student);
          await LocalDatabaseService.removeSyncOperation(op['id']);
          _logger.d('✅ Pre-loaded student $qrToken');
        }
        break;
    }
  }

  /// Trigger immediate sync (e.g., when coming back online)
  static void _triggerImmediateSync() {
    _logger.i('🔄 Triggering immediate sync due to connectivity change');
    Future.delayed(Duration(seconds: 1), _performBackgroundSync);
  }

  /// Pre-warm network connections for faster requests
  static Future<void> _preWarmConnections() async {
    try {
      if (await _isOnline()) {
        _logger.d('🔥 Pre-warming network connections...');
        // Make a lightweight request to warm up the connection
        AttendanceService.checkStudent('warmup-request').catchError((_) {
          // Ignore errors - this is just for warming up
          return <String, dynamic>{'success': false, 'error': 'warmup'};
        });
      }
    } catch (e) {
      _logger.w('⚠️ Failed to pre-warm connections: $e');
    }
  }

  /// Load frequently scanned students into cache
  static Future<void> _loadFrequentStudents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final frequentTokens = prefs.getStringList('frequent_qr_tokens') ?? [];

      if (frequentTokens.isNotEmpty && await _isOnline()) {
        _logger.d('📚 Loading ${frequentTokens.length} frequent students');
        await LocalDatabaseService.preloadFrequentStudents(frequentTokens);
      }
    } catch (e) {
      _logger.w('⚠️ Failed to load frequent students: $e');
    }
  }

  /// Update list of frequently scanned students
  static Future<void> updateFrequentStudents(List<String> qrTokens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('frequent_qr_tokens', qrTokens);
      _logger.d('📝 Updated frequent students list');
    } catch (e) {
      _logger.e('❌ Failed to update frequent students: $e');
    }
  }

  /// Get service statistics
  static Future<Map<String, dynamic>> getServiceStats() async {
    final dbStats = await LocalDatabaseService.getDatabaseStats();

    return {
      ...dbStats,
      'recent_scans': _recentScans.length,
      'is_online': await _isOnline(),
      'connectivity': _lastConnectivityState?.name,
      'sync_timer_active': _backgroundSyncTimer?.isActive ?? false,
    };
  }

  /// Manual sync trigger (for testing or user-initiated sync)
  static Future<Map<String, dynamic>> forcSync() async {
    _logger.i('🔄 Manual sync triggered');

    final beforeStats = await LocalDatabaseService.getDatabaseStats();
    await _performBackgroundSync();
    final afterStats = await LocalDatabaseService.getDatabaseStats();

    return {
      'success': true,
      'before_pending': beforeStats['pending_sync'] ?? 0,
      'after_pending': afterStats['pending_sync'] ?? 0,
      'synced_operations':
          (beforeStats['pending_sync'] ?? 0) -
          (afterStats['pending_sync'] ?? 0),
    };
  }

  /// Dispose of service resources
  static Future<void> dispose() async {
    _logger.i('🔐 Disposing InstantAttendanceService...');

    _connectivitySubscription?.cancel();
    _backgroundSyncTimer?.cancel();
    _recentScans.clear();
    _scanTimestamps.clear();

    await LocalDatabaseService.close();
    AttendanceService.dispose();

    _logger.i('✅ InstantAttendanceService disposed');
  }
}
