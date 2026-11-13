import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/features/attendance/data/models/attendance_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Explicit tier classifications for attendance synchronization.
enum AttendanceRecordTier {
  /// Check-in / check-out confirmed by backend server (200 OK acknowledgment).
  apiConfirmed,

  /// Saved to local SQLite database, pending background server sync.
  locallySaved,

  /// Demonstration baseline records (e.g. past history from mock seeds).
  demoOnly,
}

/// Shared persistent attendance store providing synchronization between
/// Employee mobile scanning and Admin dashboard views.
///
/// Bridges stateless mock REST APIs by guaranteeing that real QR check-ins
/// performed on the device are persisted and immediately retrievable by Admin.
class SharedAttendanceSyncStore {
  SharedAttendanceSyncStore._();

  static final SharedAttendanceSyncStore instance =
      SharedAttendanceSyncStore._();

  static const String _prefKey = 'shared_attendance_records_v2';

  final List<AttendanceModel> _inMemoryRecords = [];
  bool _isHydrated = false;

  final StreamController<AttendanceModel> _attendanceChangeController =
      StreamController<AttendanceModel>.broadcast();

  /// Broadcast stream notifying listeners whenever an attendance record is saved.
  Stream<AttendanceModel> get onAttendanceChanged =>
      _attendanceChangeController.stream;

  /// Determines the explicit tier of an attendance record.
  static AttendanceRecordTier getRecordTier(AttendanceModel record) {
    if (record.syncStatus == AppConstants.syncServerConfirmed) {
      return AttendanceRecordTier.apiConfirmed;
    }
    if (record.syncStatus == AppConstants.syncLocalPending) {
      return AttendanceRecordTier.locallySaved;
    }
    return AttendanceRecordTier.demoOnly;
  }

  /// Saves or updates a real attendance record.
  Future<void> saveRecord(AttendanceModel record) async {
    await _ensureHydrated(force: true);

    final normEmpId = record.employeeId.toUpperCase().trim();
    final index = _inMemoryRecords.indexWhere(
      (r) =>
          r.employeeId.toUpperCase().trim() == normEmpId &&
          r.dateKey == record.dateKey,
    );

    if (index >= 0) {
      _inMemoryRecords[index] = record;
    } else {
      _inMemoryRecords.add(record);
    }

    await _persist();

    debugPrint(
      '[ATTENDANCE_DEBUG][Step 7] SharedAttendanceSyncStore.saveRecord successful: empId=${record.employeeId}, '
      'dateKey=${record.dateKey}, checkInTime=${record.checkInTime}, '
      'status=${record.status}, syncStatus=${record.syncStatus}',
    );
    debugPrint(
      '[ATTENDANCE_DEBUG][SyncStore] Write result: totalPersistedRecords=${_inMemoryRecords.length}',
    );

    debugPrint(
      '[ATTENDANCE_DEBUG][Step 8] onAttendanceChanged emitted: empId=${record.employeeId}, status=${record.status}',
    );
    _attendanceChangeController.add(record);
  }

  /// Retrieves all synchronized records matching optional [dateKey] and [employeeId].
  Future<List<AttendanceModel>> getRecords({
    String? dateKey,
    String? employeeId,
    bool forceReload = true,
  }) async {
    await _ensureHydrated(force: forceReload);

    final filtered = _inMemoryRecords.where((r) {
      if (employeeId != null && employeeId.isNotEmpty) {
        if (r.employeeId.toUpperCase().trim() !=
            employeeId.toUpperCase().trim()) {
          return false;
        }
      }
      if (dateKey != null && dateKey.isNotEmpty) {
        if (r.dateKey != dateKey) {
          return false;
        }
      }
      return true;
    }).toList();

    debugPrint(
      '[ATTENDANCE_DEBUG][SyncStore] getRecords: found ${filtered.length} records '
      '(matching dateKey=$dateKey, employeeId=$employeeId, totalInMemory=${_inMemoryRecords.length})',
    );

    return filtered;
  }

  /// Retrieves the today record for an employee, if one exists.
  Future<AttendanceModel?> getTodayRecord({
    required String employeeId,
    required String dateKey,
  }) async {
    final list = await getRecords(
      dateKey: dateKey,
      employeeId: employeeId,
      forceReload: true,
    );
    return list.isNotEmpty ? list.last : null;
  }

  /// Clear store (primarily used in automated unit tests).
  Future<void> clearForTesting() async {
    _inMemoryRecords.clear();
    _isHydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
  }

  Future<void> _ensureHydrated({bool force = false}) async {
    if (_isHydrated && !force) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawList = prefs.getStringList(_prefKey);
      if (rawList != null) {
        _inMemoryRecords.clear();
        for (final raw in rawList) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final model = AttendanceModel.fromMap(map);
            final normId = model.employeeId.toUpperCase().trim();
            if (!_inMemoryRecords.any(
              (r) =>
                  r.employeeId.toUpperCase().trim() == normId &&
                  r.dateKey == model.dateKey,
            )) {
              _inMemoryRecords.add(model);
            }
          } catch (_) {}
        }
      }
      debugPrint(
        '[ATTENDANCE_DEBUG][SyncStore] _ensureHydrated: reloaded from storage, '
        'totalRecords=${_inMemoryRecords.length}',
      );
    } catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][SyncStore] _ensureHydrated error: $e');
    }
    _isHydrated = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list =
          _inMemoryRecords.map((r) => jsonEncode(r.toMap())).toList();
      await prefs.setStringList(_prefKey, list);
    } catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][SyncStore] _persist error: $e');
    }
  }
}

