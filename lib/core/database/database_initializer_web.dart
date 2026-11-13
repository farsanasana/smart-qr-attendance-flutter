import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

bool _isDatabaseFactoryInitialized = false;

/// Initializes the Web FFI database factory for Flutter Web (IndexedDB-backed SQLite).
/// Uses `databaseFactoryFfiWebNoWebWorker` to avoid browser SharedWorker initialization
/// errors while executing SQLite directly backed by IndexedDB.
void initPlatformDatabase() {
  if (_isDatabaseFactoryInitialized) return;
  _isDatabaseFactoryInitialized = true;
  debugPrint(
    '[ATTENDANCE_DEBUG][Database] Web SQLite factory initialized with databaseFactoryFfiWebNoWebWorker',
  );
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

