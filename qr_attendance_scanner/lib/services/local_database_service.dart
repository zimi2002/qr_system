import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import 'package:qr_attendance_scanner/models/student.dart';

class LocalDatabaseService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 0, colors: true, printEmojis: true),
  );

  static Database? _database;
  static const String _dbName = 'attendance_cache.db';
  static const String _studentsTable = 'students';
  static const String _attendanceTable = 'attendance_records';
  static const String _syncQueueTable = 'sync_queue';

  /// Get database instance (singleton)
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the local database
  static Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onOpen: (db) {
        _logger.d('📁 Local database opened successfully');
      },
    );
  }

  /// Create database tables
  static Future<void> _createTables(Database db, int version) async {
    // Students cache table
    await db.execute('''
      CREATE TABLE $_studentsTable (
        qr_token TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        name TEXT NOT NULL,
        batch TEXT NOT NULL,
        mentor TEXT,
        sts TEXT NOT NULL,
        in_time TEXT,
        last_scan TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Attendance records table for offline tracking
    await db.execute('''
      CREATE TABLE $_attendanceTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        qr_token TEXT NOT NULL,
        scan_time INTEGER NOT NULL,
        status TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // Sync queue for pending operations
    await db.execute('''
      CREATE TABLE $_syncQueueTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        qr_token TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT,
        priority INTEGER DEFAULT 1,
        retry_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_qr_token ON $_studentsTable (qr_token)');
    await db.execute('CREATE INDEX idx_scan_time ON $_attendanceTable (scan_time)');
    await db.execute('CREATE INDEX idx_sync_priority ON $_syncQueueTable (priority DESC, created_at ASC)');

    _logger.i('🗃️ Database tables created successfully');
  }

  /// Check if student exists in local cache
  static Future<Student?> getCachedStudent(String qrToken) async {
    try {
      final db = await database;
      final result = await db.query(
        _studentsTable,
        where: 'qr_token = ?',
        whereArgs: [qrToken],
      );

      if (result.isEmpty) return null;

      final data = result.first;
      return Student(
        qrToken: data['qr_token'] as String,
        username: data['username'] as String,
        name: data['name'] as String,
        batch: data['batch'] as String,
        mentor: (data['mentor'] as String?) ?? '',
        sts: data['sts'] as String,
        inTime: (data['in_time'] as String?) ?? '',
        lastScan: (data['last_scan'] as String?) ?? '',
      );
    } catch (e) {
      _logger.e('❌ Error getting cached student: $e');
      return null;
    }
  }

  /// Cache student data for instant future access
  static Future<void> cacheStudent(Student student) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        _studentsTable,
        {
          'qr_token': student.qrToken,
          'username': student.username,
          'name': student.name,
          'batch': student.batch,
          'mentor': student.mentor,
          'sts': student.sts,
          'in_time': student.inTime,
          'last_scan': student.lastScan,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _logger.d('💾 Cached student: ${student.name}');
    } catch (e) {
      _logger.e('❌ Error caching student: $e');
    }
  }

  /// Update student status in cache
  static Future<void> updateStudentStatus(String qrToken, String status) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        _studentsTable,
        {
          'sts': status,
          'last_scan': DateTime.now().toIso8601String(),
          'updated_at': now,
        },
        where: 'qr_token = ?',
        whereArgs: [qrToken],
      );

      _logger.d('🔄 Updated student status: $qrToken -> $status');
    } catch (e) {
      _logger.e('❌ Error updating student status: $e');
    }
  }

  /// Check if student was recently scanned (within last 5 minutes)
  static Future<bool> wasRecentlyScanned(String qrToken) async {
    try {
      final db = await database;
      final fiveMinutesAgo = DateTime.now()
          .subtract(Duration(minutes: 5))
          .millisecondsSinceEpoch;

      final result = await db.query(
        _attendanceTable,
        where: 'qr_token = ? AND scan_time > ?',
        whereArgs: [qrToken, fiveMinutesAgo],
        orderBy: 'scan_time DESC',
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      _logger.e('❌ Error checking recent scan: $e');
      return false;
    }
  }

  /// Record attendance scan locally
  static Future<void> recordAttendanceScan(
    String qrToken,
    String status, {
    bool synced = false,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(_attendanceTable, {
        'qr_token': qrToken,
        'scan_time': now,
        'status': status,
        'synced': synced ? 1 : 0,
        'created_at': now,
      });

      _logger.d('📝 Recorded attendance: $qrToken -> $status');
    } catch (e) {
      _logger.e('❌ Error recording attendance: $e');
    }
  }

  /// Add operation to sync queue
  static Future<void> addToSyncQueue(
    String qrToken,
    String action, {
    Map<String, dynamic>? data,
    int priority = 1,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(_syncQueueTable, {
        'qr_token': qrToken,
        'action': action,
        'data': data != null ? jsonEncode(data) : null,
        'priority': priority,
        'retry_count': 0,
        'created_at': now,
      });

      _logger.d('📤 Added to sync queue: $action for $qrToken');
    } catch (e) {
      _logger.e('❌ Error adding to sync queue: $e');
    }
  }

  /// Get pending sync operations
  static Future<List<Map<String, dynamic>>> getPendingSyncOperations() async {
    try {
      final db = await database;
      return await db.query(
        _syncQueueTable,
        orderBy: 'priority DESC, created_at ASC',
        limit: 10, // Process in batches
      );
    } catch (e) {
      _logger.e('❌ Error getting sync operations: $e');
      return [];
    }
  }

  /// Remove sync operation after successful completion
  static Future<void> removeSyncOperation(int id) async {
    try {
      final db = await database;
      await db.delete(_syncQueueTable, where: 'id = ?', whereArgs: [id]);
      _logger.d('✅ Removed sync operation: $id');
    } catch (e) {
      _logger.e('❌ Error removing sync operation: $e');
    }
  }

  /// Update retry count for failed sync operation
  static Future<void> updateSyncRetryCount(int id, int retryCount) async {
    try {
      final db = await database;
      await db.update(
        _syncQueueTable,
        {'retry_count': retryCount},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      _logger.e('❌ Error updating retry count: $e');
    }
  }

  /// Pre-load frequently scanned students
  static Future<void> preloadFrequentStudents(List<String> qrTokens) async {
    try {
      final db = await database;

      // Get students that don't exist in cache
      final existingTokens = await db.query(
        _studentsTable,
        columns: ['qr_token'],
        where: 'qr_token IN (${qrTokens.map((_) => '?').join(',')})',
        whereArgs: qrTokens,
      );

      final existing = existingTokens.map((row) => row['qr_token']).toSet();
      final missing = qrTokens.where((token) => !existing.contains(token)).toList();

      if (missing.isNotEmpty) {
        _logger.i('🔄 Pre-loading ${missing.length} students for faster access');
        // This would be called by background service to fetch missing students
        for (final token in missing) {
          await addToSyncQueue(token, 'preload', priority: 2);
        }
      }
    } catch (e) {
      _logger.e('❌ Error preloading students: $e');
    }
  }

  /// Clear old cache data to keep database size manageable
  static Future<void> cleanupOldData() async {
    try {
      final db = await database;
      final thirtyDaysAgo = DateTime.now()
          .subtract(Duration(days: 30))
          .millisecondsSinceEpoch;

      // Clean up old attendance records
      await db.delete(
        _attendanceTable,
        where: 'created_at < ? AND synced = 1',
        whereArgs: [thirtyDaysAgo],
      );

      // Clean up old cached students that haven't been accessed
      await db.delete(
        _studentsTable,
        where: 'updated_at < ?',
        whereArgs: [thirtyDaysAgo],
      );

      _logger.d('🧹 Cleaned up old database entries');
    } catch (e) {
      _logger.e('❌ Error cleaning up database: $e');
    }
  }

  /// Get database statistics
  static Future<Map<String, int>> getDatabaseStats() async {
    try {
      final db = await database;

      final studentCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_studentsTable'),
      ) ?? 0;

      final attendanceCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_attendanceTable'),
      ) ?? 0;

      final pendingSyncCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_syncQueueTable'),
      ) ?? 0;

      return {
        'cached_students': studentCount,
        'attendance_records': attendanceCount,
        'pending_sync': pendingSyncCount,
      };
    } catch (e) {
      _logger.e('❌ Error getting database stats: $e');
      return {};
    }
  }

  /// Close database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.d('🔐 Database connection closed');
    }
  }
}