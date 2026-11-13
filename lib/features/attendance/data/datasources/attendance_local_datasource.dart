import 'package:flutter/foundation.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/database/app_database.dart';
import 'package:newwone/features/attendance/data/models/attendance_model.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite datasource for attendance CRUD, duplicate checks, and filters.
class AttendanceLocalDataSource {
  AttendanceLocalDataSource({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  final AppDatabase _appDatabase;

  Future<int> insertAttendance(AttendanceModel record) async {
    try {
      final db = await _appDatabase.database;
      final id = await db.insert(
        AppDatabase.attendanceTable,
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint(
        '[ATTENDANCE_DEBUG][Step 6] SQLite insert successful: id=$id, '
        'empId=${record.employeeId}, dateKey=${record.dateKey}, status=${record.status}',
      );
      return id;
    } catch (e, stack) {
      debugPrint(
        '[ATTENDANCE_DEBUG][SQLite] insertAttendance ERROR: $e\n$stack',
      );
      return record.id ?? -1;
    }
  }

  Future<void> updateCheckOut({
    required int id,
    required String checkoutSessionId,
    required String checkoutQrToken,
    required DateTime checkOutTime,
    required double latitude,
    required double longitude,
    required String status,
    required String attendanceType,
    required String syncStatus,
    String? syncError,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        AppDatabase.attendanceTable,
        {
          'checkout_session_id': checkoutSessionId,
          'checkout_qr_token': checkoutQrToken,
          'check_out_time': checkOutTime.toIso8601String(),
          'checkout_latitude': latitude,
          'checkout_longitude': longitude,
          'status': status,
          'attendance_type': attendanceType,
          'sync_status': syncStatus,
          'sync_error': syncError,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint(
        '[ATTENDANCE_DEBUG][SQLite] updateCheckOut SUCCESS: id=$id, checkOutTime=$checkOutTime',
      );
    } catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][SQLite] updateCheckOut ERROR: $e');
    }
  }

  Future<void> markQrSessionConsumed({
    required String sessionId,
    required String employeeId,
    required DateTime consumedAt,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        AppDatabase.qrSessionsTable,
        {
          'consumed_at': consumedAt.toUtc().toIso8601String(),
          'consumed_by': employeeId,
        },
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][SQLite] markQrSessionConsumed ERROR: $e');
    }
  }

  Future<void> updateSyncStatus({
    required int id,
    required String syncStatus,
    String? syncError,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        AppDatabase.attendanceTable,
        {
          'sync_status': syncStatus,
          'sync_error': syncError,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][SQLite] updateSyncStatus ERROR: $e');
    }
  }

  Future<AttendanceModel?> getTodayAttendance({
    required String employeeId,
    required String dateKey,
  }) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        AppDatabase.attendanceTable,
        where: 'LOWER(employee_id) = LOWER(?) AND date_key = ?',
        whereArgs: [employeeId, dateKey],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AttendanceModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][SQLite] getTodayAttendance ERROR: $e');
      return null;
    }
  }

  Future<bool> hasCheckedInForDate({
    required String employeeId,
    required String dateKey,
  }) async {
    final record = await getTodayAttendance(
      employeeId: employeeId,
      dateKey: dateKey,
    );
    return record != null && record.checkInTime != null;
  }

  Future<bool> hasCheckedOutForDate({
    required String employeeId,
    required String dateKey,
  }) async {
    final record = await getTodayAttendance(
      employeeId: employeeId,
      dateKey: dateKey,
    );
    return record != null && record.checkOutTime != null;
  }

  Future<List<AttendanceModel>> getAttendanceHistory({
    String? employeeId,
    String? dateKey,
    String? startDateKey,
    String? endDateKey,
  }) async {
    try {
      final db = await _appDatabase.database;
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (employeeId != null && employeeId.isNotEmpty) {
        whereClauses.add('LOWER(employee_id) = LOWER(?)');
        whereArgs.add(employeeId);
      }
      if (dateKey != null && dateKey.isNotEmpty) {
        whereClauses.add('date_key = ?');
        whereArgs.add(dateKey);
      }
      if (startDateKey != null && startDateKey.isNotEmpty) {
        whereClauses.add('date_key >= ?');
        whereArgs.add(startDateKey);
      }
      if (endDateKey != null && endDateKey.isNotEmpty) {
        whereClauses.add('date_key <= ?');
        whereArgs.add(endDateKey);
      }

      final rows = await db.query(
        AppDatabase.attendanceTable,
        where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'date_key DESC, created_at DESC',
      );
      return rows.map(AttendanceModel.fromMap).toList();
    } catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][SQLite] getAttendanceHistory ERROR: $e');
      return [];
    }
  }

  Future<List<AttendanceModel>> getPendingSyncRecords({
    String? employeeId,
  }) async {
    try {
      final db = await _appDatabase.database;
      final where = employeeId != null
          ? 'sync_status != ? AND LOWER(employee_id) = LOWER(?)'
          : 'sync_status != ?';
      final args = employeeId != null
          ? [AppConstants.syncServerConfirmed, employeeId]
          : [AppConstants.syncServerConfirmed];

      final rows = await db.query(
        AppDatabase.attendanceTable,
        where: where,
        whereArgs: args,
        orderBy: 'created_at ASC',
      );
      return rows.map(AttendanceModel.fromMap).toList();
    } catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][SQLite] getPendingSyncRecords ERROR: $e');
      return [];
    }
  }

  Future<int> getPendingCount(String employeeId) async {
    final pending = await getPendingSyncRecords(employeeId: employeeId);
    return pending.length;
  }
}

