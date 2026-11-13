import 'package:flutter/foundation.dart';
import 'package:newwone/core/database/database_initializer.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton SQLite database manager for local attendance and QR session persistence.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _databaseName = 'smart_attendance.db';
  static const int _databaseVersion = 2;

  static const String attendanceTable = 'attendance';
  static const String qrSessionsTable = 'qr_sessions';

  Database? _database;
  Future<Database>? _initFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _initFuture ??= _initDatabase();
    try {
      _database = await _initFuture!;
      return _database!;
    } finally {
      _initFuture = null;
    }
  }

  Future<Database> _initDatabase() async {
    initAppDatabaseFactory();
    final String path;
    if (kIsWeb) {
      path = _databaseName;
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, _databaseName);
    }
    debugPrint(
      '[ATTENDANCE_DEBUG][AppDatabase] Opening SQLite database at "$path" (kIsWeb=$kIsWeb)',
    );
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $attendanceTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        session_id TEXT NOT NULL,
        checkout_session_id TEXT,
        qr_token TEXT,
        checkout_qr_token TEXT,
        attendance_type TEXT NOT NULL,
        check_in_time TEXT,
        check_out_time TEXT,
        latitude REAL,
        longitude REAL,
        checkout_latitude REAL,
        checkout_longitude REAL,
        status TEXT NOT NULL,
        date_key TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'local_pending',
        sync_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_attendance_emp_date
      ON $attendanceTable (employee_id, date_key)
    ''');

    await db.execute('''
      CREATE TABLE $qrSessionsTable (
        session_id TEXT PRIMARY KEY,
        qr_token TEXT NOT NULL,
        attendance_type TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        generated_by TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'local_pending',
        consumed_at TEXT,
        consumed_by TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _ensureColumnExists(
        db,
        attendanceTable,
        'checkout_session_id',
        'TEXT',
      );
      await _ensureColumnExists(db, attendanceTable, 'qr_token', 'TEXT');
      await _ensureColumnExists(
        db,
        attendanceTable,
        'checkout_qr_token',
        'TEXT',
      );
      await _ensureColumnExists(db, qrSessionsTable, 'consumed_at', 'TEXT');
      await _ensureColumnExists(db, qrSessionsTable, 'consumed_by', 'TEXT');
    }
  }

  Future<void> _ensureColumnExists(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name']?.toString() == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

