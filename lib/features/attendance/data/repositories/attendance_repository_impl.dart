import 'package:flutter/foundation.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/network/api_exception.dart';
import 'package:newwone/core/sync/shared_attendance_sync_store.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/features/attendance/data/datasources/attendance_api_service.dart';
import 'package:newwone/features/attendance/data/datasources/attendance_local_datasource.dart';
import 'package:newwone/features/attendance/data/models/attendance_model.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';
import 'package:newwone/features/attendance/domain/repositories/attendance_repository.dart';

/// Domain validation exception for attendance business rules.
class AttendanceRuleException implements Exception {
  const AttendanceRuleException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    required AttendanceLocalDataSource localDataSource,
    required AttendanceApiService apiService,
  })  : _localDataSource = localDataSource,
        _apiService = apiService;

  final AttendanceLocalDataSource _localDataSource;
  final AttendanceApiService _apiService;

  @override
  Future<AttendanceEntity?> getTodayAttendance(String employeeId) async {
    final todayKey = AppDateUtils.toDateKey(DateTime.now());
    final local = await _localDataSource.getTodayAttendance(
      employeeId: employeeId,
      dateKey: todayKey,
    );
    if (local != null) return local;

    final shared = await SharedAttendanceSyncStore.instance.getTodayRecord(
      employeeId: employeeId,
      dateKey: todayKey,
    );
    if (shared != null) {
      await _localDataSource.insertAttendance(shared);
      return shared;
    }

    try {
      final remote = await _apiService.getTodayAttendance(employeeId);
      // Only treat remote record as today's attendance if it contains an actual,
      // explicit checkInTime timestamp and matches today's date.
      if (remote != null &&
          remote.checkInTime != null &&
          remote.dateKey == todayKey) {
        // Cache in local SQLite so subsequent lookups succeed immediately
        await _localDataSource.insertAttendance(remote);
        await SharedAttendanceSyncStore.instance.saveRecord(remote);
        return remote;
      }
      return null;
    } on ApiException {
      return null;
    }
  }

  @override
  Future<List<AttendanceEntity>> getAttendanceHistory({
    required String employeeId,
    AttendanceDateFilter filter = AttendanceDateFilter.all,
    DateTime? customDate,
  }) async {
    final now = DateTime.now();
    String? dateKey;
    String? startDateKey;
    String? endDateKey;

    switch (filter) {
      case AttendanceDateFilter.all:
        break;
      case AttendanceDateFilter.today:
        dateKey = AppDateUtils.toDateKey(now);
      case AttendanceDateFilter.thisWeek:
        final weekdayOffset = now.weekday - 1;
        final monday = now.subtract(Duration(days: weekdayOffset));
        startDateKey = AppDateUtils.toDateKey(monday);
        endDateKey = AppDateUtils.toDateKey(now);
      case AttendanceDateFilter.thisMonth:
        final firstOfMonth = DateTime(now.year, now.month, 1);
        startDateKey = AppDateUtils.toDateKey(firstOfMonth);
        endDateKey = AppDateUtils.toDateKey(now);
      case AttendanceDateFilter.customDate:
        if (customDate != null) {
          dateKey = AppDateUtils.toDateKey(customDate);
        }
    }

    final localRecords = await _localDataSource.getAttendanceHistory(
      employeeId: employeeId,
      dateKey: dateKey,
      startDateKey: startDateKey,
      endDateKey: endDateKey,
    );

    final combinedMap = <String, AttendanceEntity>{};
    // 1. Add local records (local check-ins take precedence for today)
    for (final rec in localRecords) {
      combinedMap[rec.dateKey] = rec;
    }

    // 2. Fetch remote records to merge historical logs not yet in local SQLite
    if (filter == AttendanceDateFilter.all || localRecords.isEmpty) {
      try {
        final remoteRecords = await _apiService.getHistory(employeeId);
        for (final rec in remoteRecords) {
          combinedMap.putIfAbsent(rec.dateKey, () => rec);
        }
      } on ApiException {
        // Continue with local records
      }
    }

    final combined = combinedMap.values.toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return combined;
  }

  @override
  Future<AttendanceWriteResult> submitCheckIn({
    required String employeeId,
    required String employeeName,
    required String sessionId,
    required String qrToken,
    required double latitude,
    required double longitude,
  }) async {
    final now = DateTime.now();
    final todayKey = AppDateUtils.toDateKey(now);

    debugPrint(
      '[ATTENDANCE_DEBUG][Step 5] AttendanceRepository.submitCheckIn called: '
      'employeeId=$employeeId, employeeName=$employeeName, sessionId=$sessionId, qrToken=$qrToken',
    );

    final alreadyCheckedIn = await _localDataSource.hasCheckedInForDate(
      employeeId: employeeId,
      dateKey: todayKey,
    );
    if (alreadyCheckedIn) {
      throw const AttendanceRuleException(
        'Duplicate check-in prevented: You have already checked in today.',
      );
    }

    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
      AppConstants.workStartHour,
      AppConstants.workStartMinute,
    );
    final status = now.isAfter(cutoff)
        ? AppConstants.statusLate
        : AppConstants.statusPresent;

    debugPrint(
      '[ATTENDANCE_DEBUG][AttendanceRepo] Attendance date key: $todayKey, '
      'Check-In timestamp: ${now.toIso8601String()}, status: $status',
    );

    final draft = AttendanceModel(
      employeeId: employeeId,
      employeeName: employeeName,
      sessionId: sessionId,
      qrToken: qrToken,
      attendanceType: AppConstants.typeCheckIn,
      checkInTime: now,
      latitude: latitude,
      longitude: longitude,
      status: status,
      dateKey: todayKey,
      syncStatus: AppConstants.syncLocalPending,
      createdAt: now,
    );

    final insertedId = await _localDataSource.insertAttendance(draft);
    debugPrint(
      '[ATTENDANCE_DEBUG][AttendanceRepo] SQLite insert result: insertedId=$insertedId',
    );

    await _localDataSource.markQrSessionConsumed(
      sessionId: sessionId,
      employeeId: employeeId,
      consumedAt: now,
    );
    var saved = draft.copyWith(id: insertedId);

    try {
      await _apiService.checkIn(saved, qrToken: qrToken);
      await _localDataSource.updateSyncStatus(
        id: insertedId,
        syncStatus: AppConstants.syncServerConfirmed,
      );
      saved = saved.copyWith(
        syncStatus: AppConstants.syncServerConfirmed,
        clearSyncError: true,
      );
      await SharedAttendanceSyncStore.instance.saveRecord(saved);
      debugPrint(
        '[ATTENDANCE_DEBUG][AttendanceRepo] SharedAttendanceSyncStore write result: '
        'saved record with syncStatus=${saved.syncStatus}',
      );
      return AttendanceWriteResult(
        record: saved,
        isServerConfirmed: true,
      );
    } on ApiException catch (e) {
      await _localDataSource.updateSyncStatus(
        id: insertedId,
        syncStatus: AppConstants.syncLocalPending,
        syncError: e.message,
      );
      saved = saved.copyWith(
        syncStatus: AppConstants.syncLocalPending,
        syncError: e.message,
      );
      await SharedAttendanceSyncStore.instance.saveRecord(saved);
      debugPrint(
        '[ATTENDANCE_DEBUG][AttendanceRepo] SharedAttendanceSyncStore write result: '
        'saved record with syncStatus=${saved.syncStatus} (warning: ${e.message})',
      );
      return AttendanceWriteResult(
        record: saved,
        isServerConfirmed: false,
        warningMessage: e.message,
      );
    }
  }

  @override
  Future<AttendanceWriteResult> submitCheckOut({
    required String employeeId,
    required String employeeName,
    required String sessionId,
    required String qrToken,
    required double latitude,
    required double longitude,
  }) async {
    final now = DateTime.now();
    final todayKey = AppDateUtils.toDateKey(now);

    debugPrint(
      '[ATTENDANCE_DEBUG][Step 5] AttendanceRepository.submitCheckOut called: '
      'employeeId=$employeeId, employeeName=$employeeName, sessionId=$sessionId, qrToken=$qrToken',
    );

    final existing = await _localDataSource.getTodayAttendance(
      employeeId: employeeId,
      dateKey: todayKey,
    );

    if (existing == null || existing.checkInTime == null) {
      throw const AttendanceRuleException(
        'Check-out denied: No valid check-in found for today. Please scan a Check-In QR code first.',
      );
    }

    if (existing.checkOutTime != null) {
      throw const AttendanceRuleException(
        'Duplicate check-out prevented: You have already checked out today.',
      );
    }

    if (existing.sessionId == sessionId) {
      throw const AttendanceRuleException(
        'Check-out denied: Cannot reuse Check-In session ID for Check-Out.',
      );
    }

    final recordId = existing.id!;
    var updated = AttendanceModel.fromEntity(existing).copyWith(
      checkoutSessionId: sessionId,
      checkoutQrToken: qrToken,
      checkOutTime: now,
      checkoutLatitude: latitude,
      checkoutLongitude: longitude,
      attendanceType: AppConstants.typeCheckOut,
      status: AppConstants.statusCheckedOut,
      syncStatus: AppConstants.syncLocalPending,
    );

    await _localDataSource.updateCheckOut(
      id: recordId,
      checkoutSessionId: sessionId,
      checkoutQrToken: qrToken,
      checkOutTime: now,
      latitude: latitude,
      longitude: longitude,
      status: AppConstants.statusCheckedOut,
      attendanceType: AppConstants.typeCheckOut,
      syncStatus: AppConstants.syncLocalPending,
    );
    await _localDataSource.markQrSessionConsumed(
      sessionId: sessionId,
      employeeId: employeeId,
      consumedAt: now,
    );

    debugPrint(
      '[ATTENDANCE_DEBUG][AttendanceRepo] submitCheckOut SQLite updated: recordId=$recordId, checkOutTime=$now',
    );

    try {
      await _apiService.checkOut(updated, qrToken: qrToken);
      await _localDataSource.updateSyncStatus(
        id: recordId,
        syncStatus: AppConstants.syncServerConfirmed,
      );
      updated = updated.copyWith(
        syncStatus: AppConstants.syncServerConfirmed,
        clearSyncError: true,
      );
      await SharedAttendanceSyncStore.instance.saveRecord(updated);
      debugPrint(
        '[ATTENDANCE_DEBUG][AttendanceRepo] submitCheckOut SharedAttendanceSyncStore write result: '
        'status=${updated.status}, syncStatus=${updated.syncStatus}',
      );
      return AttendanceWriteResult(
        record: updated,
        isServerConfirmed: true,
      );
    } on ApiException catch (e) {
      await _localDataSource.updateSyncStatus(
        id: recordId,
        syncStatus: AppConstants.syncLocalPending,
        syncError: e.message,
      );
      updated = updated.copyWith(
        syncStatus: AppConstants.syncLocalPending,
        syncError: e.message,
      );
      await SharedAttendanceSyncStore.instance.saveRecord(updated);
      debugPrint(
        '[ATTENDANCE_DEBUG][AttendanceRepo] submitCheckOut SharedAttendanceSyncStore write result: '
        'status=${updated.status}, syncStatus=${updated.syncStatus} (warning: ${e.message})',
      );
      return AttendanceWriteResult(
        record: updated,
        isServerConfirmed: false,
        warningMessage: e.message,
      );
    }
  }

  @override
  Future<AttendanceWriteResult> retrySyncRecord(AttendanceEntity record) async {
    final model = AttendanceModel.fromEntity(record);
    if (model.id == null) {
      throw const AttendanceRuleException('Cannot sync record without local ID.');
    }

    try {
      if (model.isCheckedOut) {
        await _apiService.checkOut(
          model,
          qrToken: model.checkoutQrToken ?? model.qrToken,
        );
      } else {
        await _apiService.checkIn(
          model,
          qrToken: model.qrToken,
        );
      }
      await _localDataSource.updateSyncStatus(
        id: model.id!,
        syncStatus: AppConstants.syncServerConfirmed,
      );
      final synced = model.copyWith(
        syncStatus: AppConstants.syncServerConfirmed,
        clearSyncError: true,
      );
      await SharedAttendanceSyncStore.instance.saveRecord(synced);
      return AttendanceWriteResult(
        record: synced,
        isServerConfirmed: true,
      );
    } on ApiException catch (e) {
      await _localDataSource.updateSyncStatus(
        id: model.id!,
        syncStatus: AppConstants.syncLocalPending,
        syncError: e.message,
      );
      return AttendanceWriteResult(
        record: model.copyWith(
          syncStatus: AppConstants.syncLocalPending,
          syncError: e.message,
        ),
        isServerConfirmed: false,
        warningMessage: e.message,
      );
    }
  }

  @override
  Future<int> syncAllPending(String employeeId) async {
    final pending = await _localDataSource.getPendingSyncRecords(
      employeeId: employeeId,
    );
    int syncedCount = 0;
    for (final record in pending) {
      final result = await retrySyncRecord(record);
      if (result.isServerConfirmed) {
        syncedCount++;
      }
    }
    return syncedCount;
  }

  @override
  Future<int> getPendingCount(String employeeId) {
    return _localDataSource.getPendingCount(employeeId);
  }
}

