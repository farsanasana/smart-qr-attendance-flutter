import 'package:flutter/foundation.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/database/app_database.dart';
import 'package:newwone/core/network/api_exception.dart';
import 'package:newwone/core/sync/shared_attendance_sync_store.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/core/utils/token_generator.dart';
import 'package:newwone/features/admin/data/datasources/admin_api_service.dart';
import 'package:newwone/features/admin/data/datasources/qr_session_api_service.dart';
import 'package:newwone/features/admin/domain/entities/employee_attendance_summary.dart';
import 'package:newwone/features/admin/domain/repositories/admin_repository.dart';
import 'package:newwone/features/attendance/data/datasources/attendance_api_service.dart';
import 'package:newwone/features/attendance/data/datasources/attendance_local_datasource.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';
import 'package:newwone/features/auth/data/datasources/dummy_users.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:newwone/features/qr_scanner/domain/entities/qr_payload.dart';
import 'package:sqflite/sqflite.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl({
    required AdminApiService adminApiService,
    required QrSessionApiService qrSessionApiService,
    required AttendanceLocalDataSource attendanceLocalDataSource,
    AttendanceApiService? attendanceApiService,
    AppDatabase? appDatabase,
  })  : _adminApiService = adminApiService,
        _qrSessionApiService = qrSessionApiService,
        _attendanceLocalDataSource = attendanceLocalDataSource,
        _attendanceApiService = attendanceApiService,
        _appDatabase = appDatabase ?? AppDatabase.instance;

  final AdminApiService _adminApiService;
  final QrSessionApiService _qrSessionApiService;
  final AttendanceLocalDataSource _attendanceLocalDataSource;
  final AttendanceApiService? _attendanceApiService;
  final AppDatabase _appDatabase;

  @override
  Future<AdminOverviewData> getDashboardOverview({
    required DateTime date,
  }) async {
    final dateKey = AppDateUtils.toDateKey(date);
    debugPrint(
      '[ATTENDANCE_DEBUG][AdminRepo] getDashboardOverview START: dateKey=$dateKey',
    );
    List<UserEntity> directory = DummyUsers.employeesOnly;
    bool isFromRemoteServer = false;

    try {
      final remote = await _adminApiService.getEmployees(dateKey: dateKey);
      if (remote.isNotEmpty) {
        directory = remote
            .where((u) => u.role.toLowerCase() != AppConstants.roleAdmin)
            .toList();
        isFromRemoteServer = true;
      }
    } on ApiException catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][AdminRepo] Remote employees API offline: $e');
      isFromRemoteServer = false;
    } catch (e) {
      debugPrint('[ATTENDANCE_DEBUG][AdminRepo] Remote employees unexpected error: $e');
      isFromRemoteServer = false;
    }

    final dateAttendance = await _attendanceLocalDataSource.getAttendanceHistory(
      dateKey: dateKey,
    );
    final allAttendance =
        await _attendanceLocalDataSource.getAttendanceHistory();

    debugPrint(
      '[ATTENDANCE_DEBUG][AdminRepo] SQLite records retrieved: '
      'dateAttendance=${dateAttendance.length}, allAttendance=${allAttendance.length}',
    );

    final recordByEmpId = <String, AttendanceEntity>{};
    final historyByEmpId = <String, List<AttendanceEntity>>{};

    // 1. Populate from local SQLite table for dateKey
    for (final rec in dateAttendance) {
      recordByEmpId.putIfAbsent(rec.employeeId.toUpperCase().trim(), () => rec);
    }

    // 2. Fall back to allAttendance if checkInTime matches dateKey
    for (final rec in allAttendance) {
      final normId = rec.employeeId.toUpperCase().trim();
      historyByEmpId.putIfAbsent(normId, () => []).add(rec);
      if (rec.dateKey == dateKey ||
          (rec.checkInTime != null &&
              AppDateUtils.toDateKey(rec.checkInTime!) == dateKey)) {
        recordByEmpId.putIfAbsent(normId, () => rec);
      }
    }

    // 3. Hydrate live records from SharedAttendanceSyncStore (forcing SharedPreferences reload on web)
    final sharedToday = await SharedAttendanceSyncStore.instance.getRecords(
      dateKey: dateKey,
      forceReload: true,
    );
    final sharedAll = await SharedAttendanceSyncStore.instance.getRecords(
      forceReload: true,
    );

    debugPrint(
      '[ATTENDANCE_DEBUG][AdminRepo] SharedAttendanceSyncStore records retrieved: '
      'sharedToday=${sharedToday.length}, sharedAll=${sharedAll.length}',
    );

    for (final rec in sharedToday) {
      final normId = rec.employeeId.toUpperCase().trim();
      recordByEmpId[normId] = rec;
      debugPrint(
        '[ATTENDANCE_DEBUG][AdminRepo] Synced record mapped to employee $normId: '
        'status=${rec.status}, checkInTime=${rec.checkInTime}, syncStatus=${rec.syncStatus}',
      );
      // Also cache to local SQLite so subsequent offline DB queries find it
      try {
        await _attendanceLocalDataSource.insertAttendance(rec);
      } catch (e) {
        debugPrint('[ATTENDANCE_DEBUG][AdminRepo] SQLite cache insert ignored error: $e');
      }
    }
    for (final rec in sharedAll) {
      final normId = rec.employeeId.toUpperCase().trim();
      final list = historyByEmpId.putIfAbsent(normId, () => []);
      if (!list.any((r) => r.sessionId == rec.sessionId && r.dateKey == rec.dateKey)) {
        list.add(rec);
      }
    }

    final knownIds = directory.map((e) => e.id.toUpperCase().trim()).toSet();
    final combinedEmployees = <UserEntity>[...directory];
    for (final rec in allAttendance) {
      final normalizedId = rec.employeeId.toUpperCase().trim();
      if (!knownIds.contains(normalizedId)) {
        knownIds.add(normalizedId);
        combinedEmployees.add(
          UserEntity(
            id: rec.employeeId,
            name: rec.employeeName,
            email: '${rec.employeeId.toLowerCase()}@company.com',
            role: AppConstants.roleEmployee,
          ),
        );
      }
    }
    for (final rec in sharedAll) {
      final normalizedId = rec.employeeId.toUpperCase().trim();
      if (!knownIds.contains(normalizedId)) {
        knownIds.add(normalizedId);
        combinedEmployees.add(
          UserEntity(
            id: rec.employeeId,
            name: rec.employeeName,
            email: '${rec.employeeId.toLowerCase()}@company.com',
            role: AppConstants.roleEmployee,
          ),
        );
      }
    }

    // Synchronize remote attendance for employees without local records on dateKey
    if (_attendanceApiService != null) {
      for (final emp in combinedEmployees) {
        final normalizedId = emp.id.toUpperCase().trim();
        if (!recordByEmpId.containsKey(normalizedId)) {
          try {
            final remoteRecord =
                await _attendanceApiService.getTodayAttendance(emp.id);
            if (remoteRecord != null &&
                remoteRecord.checkInTime != null &&
                remoteRecord.dateKey == dateKey) {
              recordByEmpId[normalizedId] = remoteRecord;
              historyByEmpId
                  .putIfAbsent(normalizedId, () => [])
                  .add(remoteRecord);
              try {
                await _attendanceLocalDataSource.insertAttendance(remoteRecord);
              } catch (_) {}
              isFromRemoteServer = true;
            }
          } on ApiException {
            // Continue with local records on network error
          } catch (_) {}
        }
      }
    }

    final summaries = combinedEmployees.map((emp) {
      final normalizedId = emp.id.toUpperCase().trim();
      final rec = recordByEmpId[normalizedId];
      final summary = EmployeeAttendanceSummary(
        employee: emp,
        record: rec,
        history: historyByEmpId[normalizedId] ?? const [],
      );
      debugPrint(
        '[ATTENDANCE_DEBUG][AdminRepo] Employee ${emp.id} (${emp.name}): '
        'effectiveStatus=${summary.effectiveStatus}, isPresent=${summary.isPresentOrCompleted}, '
        'checkInTime=${rec?.checkInTime}',
      );
      return summary;
    }).toList();

    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;
    int checkedOutCount = 0;
    int checkedInCount = 0;

    for (final summary in summaries) {
      if (summary.isPresentOrCompleted) {
        presentCount++;
        if (summary.isLate) lateCount++;
        if (summary.record?.isCheckedOut ?? false) {
          checkedOutCount++;
        } else {
          checkedInCount++;
        }
      } else {
        absentCount++;
      }
    }

    debugPrint(
      '[ATTENDANCE_DEBUG][Step 10] AdminRepository calculated updated metrics: '
      'Total=${summaries.length}, Present=$presentCount, Absent=$absentCount, '
      'CheckedIn=$checkedInCount, CheckedOut=$checkedOutCount',
    );

    return AdminOverviewData(
      metrics: AdminDashboardMetrics(
        totalEmployees: summaries.length,
        presentEmployees: presentCount,
        absentEmployees: absentCount,
        lateArrivals: lateCount,
        checkedOutCount: checkedOutCount,
        checkedInCount: checkedInCount,
      ),
      employees: summaries,
      isFromRemoteServer: isFromRemoteServer,
    );
  }

  @override
  Future<QrSessionGenerationResult> generateQrSession({
    required String attendanceType,
    required int durationMinutes,
    required String adminId,
  }) async {
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(Duration(minutes: durationMinutes));
    final payload = QrPayload(
      sessionId: TokenGenerator.generateSessionId(now),
      qrToken: TokenGenerator.generateQrToken(),
      attendanceType: attendanceType,
      expiresAt: expiresAt,
      issuedAt: now,
      generatedBy: adminId,
    ).withIntegrityTag();

    bool isServerConfirmed = false;
    String? warningMessage;

    try {
      await _qrSessionApiService.createQrSession(payload);
      isServerConfirmed = true;
    } on ApiException catch (e) {
      isServerConfirmed = false;
      warningMessage = e.message;
    }

    try {
      final db = await _appDatabase.database;
      await db.insert(
        AppDatabase.qrSessionsTable,
        {
          'session_id': payload.sessionId,
          'qr_token': payload.qrToken,
          'attendance_type': payload.attendanceType,
          'expires_at': payload.expiresAt.toIso8601String(),
          'generated_by': adminId,
          'sync_status': isServerConfirmed
              ? AppConstants.syncServerConfirmed
              : AppConstants.syncLocalPending,
          'created_at': now.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Continue even if local SQLite is unavailable in unit test harness
    }

    return QrSessionGenerationResult(
      payload: payload,
      isServerConfirmed: isServerConfirmed,
      warningMessage: warningMessage,
    );
  }
}

