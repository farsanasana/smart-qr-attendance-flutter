import 'database_initializer_stub.dart'
    if (dart.library.js_interop) 'database_initializer_web.dart'
    if (dart.library.html) 'database_initializer_web.dart';

/// Initializes the appropriate SQLite database factory based on the active runtime platform.
/// On Android and iOS, sqflite automatically provides its native channel-based factory.
/// On Flutter Web, this binds `databaseFactoryFfiWeb` backed by IndexedDB.
void initAppDatabaseFactory() {
  initPlatformDatabase();
}

