import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/network/api_exception.dart';
import 'package:newwone/core/network/dio_client.dart';
import 'package:newwone/core/sync/shared_attendance_sync_store.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/core/widgets/sync_status_badge.dart';
import 'package:newwone/features/admin/data/datasources/admin_api_service.dart';
import 'package:newwone/features/admin/data/datasources/qr_session_api_service.dart';
import 'package:newwone/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:newwone/features/attendance/data/datasources/attendance_api_service.dart';
import 'package:newwone/features/attendance/data/datasources/attendance_local_datasource.dart';
import 'package:newwone/features/attendance/data/models/attendance_model.dart';
import 'package:newwone/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:newwone/features/auth/data/datasources/auth_api_service.dart';
import 'package:newwone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:newwone/features/auth/presentation/bloc/authentication_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturedRequest {
  _CapturedRequest(this.method, this.path, this.body);
  final String method;
  final String path;
  final Map<String, dynamic> body;
}

class _StubHttpAdapter implements HttpClientAdapter {
  _StubHttpAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}

class _InMemoryAttendanceLocalDataSource extends AttendanceLocalDataSource {
  final List<AttendanceModel> records = [];
  final List<String> consumedSessions = [];
  int _nextId = 1;

  @override
  Future<int> insertAttendance(AttendanceModel record) async {
    final id = _nextId++;
    records.add(record.copyWith(id: id));
    return id;
  }

  @override
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
    final index = records.indexWhere((r) => r.id == id);
    records[index] = records[index].copyWith(
      checkoutSessionId: checkoutSessionId,
      checkoutQrToken: checkoutQrToken,
      checkOutTime: checkOutTime,
      checkoutLatitude: latitude,
      checkoutLongitude: longitude,
      status: status,
      attendanceType: attendanceType,
      syncStatus: syncStatus,
      syncError: syncError,
    );
  }

  @override
  Future<void> updateSyncStatus({
    required int id,
    required String syncStatus,
    String? syncError,
  }) async {
    final index = records.indexWhere((r) => r.id == id);
    records[index] = records[index].copyWith(
      syncStatus: syncStatus,
      syncError: syncError,
      clearSyncError: syncError == null,
    );
  }

  @override
  Future<void> markQrSessionConsumed({
    required String sessionId,
    required String employeeId,
    required DateTime consumedAt,
  }) async {
    consumedSessions.add('$employeeId:$sessionId');
  }

  @override
  Future<AttendanceModel?> getTodayAttendance({
    required String employeeId,
    required String dateKey,
  }) async {
    for (final rec in records.reversed) {
      if (rec.employeeId.toLowerCase() == employeeId.toLowerCase() &&
          rec.dateKey == dateKey) {
        return rec;
      }
    }
    return null;
  }

  @override
  Future<List<AttendanceModel>> getAttendanceHistory({
    String? employeeId,
    String? dateKey,
    String? startDateKey,
    String? endDateKey,
  }) async {
    return records.where((rec) {
      if (employeeId != null &&
          rec.employeeId.toLowerCase() != employeeId.toLowerCase()) {
        return false;
      }
      if (dateKey != null && rec.dateKey != dateKey) {
        return false;
      }
      if (startDateKey != null && rec.dateKey.compareTo(startDateKey) < 0) {
        return false;
      }
      if (endDateKey != null && rec.dateKey.compareTo(endDateKey) > 0) {
        return false;
      }
      return true;
    }).toList();
  }
}

DioClient _buildMockedDioClient(
  ResponseBody Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.mock.pstmn.io'));
  dio.httpClientAdapter = _StubHttpAdapter(handler);
  return DioClient(
    dio: dio,
    baseUrl: 'https://example.mock.pstmn.io',
  );
}

ResponseBody _jsonResponse(dynamic body, int statusCode) {
  final raw = body is String ? body : jsonEncode(body);
  return ResponseBody.fromString(
    raw,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedAttendanceSyncStore.instance.clearForTesting();
  });
  group('AuthApiService empty/invalid response handling', () {
    test('rejects empty 200 OK login body', () async {
      final client = _buildMockedDioClient((_) => _jsonResponse('', 200));
      final service = AuthApiService(client);

      await expectLater(
        service.login(identifier: 'rahul@gmail.com', password: '123456'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiErrorType.serverError),
        ),
      );
    });

    test('rejects 200 OK JSON with missing user id or token', () async {
      final client = _buildMockedDioClient(
        (_) => _jsonResponse({'user': {'email': 'rahul@gmail.com'}}, 200),
      );
      final service = AuthApiService(client);

      await expectLater(
        service.login(identifier: 'rahul@gmail.com', password: '123456'),
        throwsA(isA<ApiException>()),
      );
    });

    test('parses valid 200 OK login response', () async {
      final client = _buildMockedDioClient(
        (_) => _jsonResponse({
          'token': 'jwt-123',
          'user': {
            'id': 'EMP001',
            'name': 'Rahul',
            'email': 'rahul@gmail.com',
            'role': 'employee',
          },
        }, 200),
      );
      final service = AuthApiService(client);
      final result = await service.login(
        identifier: 'rahul@gmail.com',
        password: '123456',
      );
      expect(result.user.id, 'EMP001');
      expect(result.token, 'jwt-123');
    });

    test('sends strictly email and password in POST /login body matching Postman example', () async {
      RequestOptions? capturedOptions;
      final client = _buildMockedDioClient((options) {
        capturedOptions = options;
        return _jsonResponse({
          'token': 'jwt-123',
          'user': {
            'id': 'EMP001',
            'name': 'Rahul',
            'email': 'rahul@gmail.com',
            'role': 'employee',
          },
        }, 200);
      });
      final service = AuthApiService(client);
      await service.login(
        identifier: 'rahul@gmail.com',
        password: '123456',
      );

      expect(capturedOptions?.method, 'POST');
      expect(capturedOptions?.path, '/login');
      expect(capturedOptions?.data, {
        'email': 'rahul@gmail.com',
        'password': '123456',
      });
      expect((capturedOptions?.data as Map).containsKey('identifier'), isFalse);
    });

    test('resolves employee ID EMP001 to email rahul@gmail.com for Postman mock matching', () async {
      RequestOptions? capturedOptions;
      final client = _buildMockedDioClient((options) {
        capturedOptions = options;
        return _jsonResponse({
          'token': 'jwt-123',
          'user': {
            'id': 'EMP001',
            'name': 'Rahul',
            'email': 'rahul@gmail.com',
            'role': 'employee',
          },
        }, 200);
      });
      final service = AuthApiService(client);
      await service.login(
        identifier: 'EMP001',
        password: '123456',
      );

      expect(capturedOptions?.data, {
        'email': 'rahul@gmail.com',
        'password': '123456',
      });
    });
  });

  group('AuthRepositoryImpl mock server & demo account logins', () {
    late DioClient staticRahulMockClient;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      // Simulates Postman Mock Server returning Rahul (EMP001) for any 200 POST /login
      staticRahulMockClient = _buildMockedDioClient(
        (_) => _jsonResponse({
          'success': true,
          'message': 'Login successful',
          'token': 'dummy_token_123',
          'user': {
            'id': 'EMP001',
            'name': 'Rahul',
            'email': 'rahul@gmail.com',
            'role': 'employee',
          },
        }, 200),
      );
    });

    test('Rahul (EMP001) logs in successfully with server token', () async {
      final repo = AuthRepositoryImpl(
        apiService: AuthApiService(staticRahulMockClient),
        dioClient: staticRahulMockClient,
        preferences: prefs,
      );

      final session = await repo.login(
        identifier: 'rahul@gmail.com',
        password: '123456',
      );

      expect(session.user.id, 'EMP001');
      expect(session.user.role, AppConstants.roleEmployee);
      expect(session.token, 'dummy_token_123');
      expect(session.isDemoMode, isFalse);
    });

    test('Anjali (EMP002) logs in successfully with server token', () async {
      final repo = AuthRepositoryImpl(
        apiService: AuthApiService(staticRahulMockClient),
        dioClient: staticRahulMockClient,
        preferences: prefs,
      );

      final session = await repo.login(
        identifier: 'anjali@gmail.com',
        password: '123456',
      );

      expect(session.user.id, 'EMP002');
      expect(session.user.name, 'Anjali');
      expect(session.user.role, AppConstants.roleEmployee);
      expect(session.token, 'dummy_token_123');
      expect(session.isDemoMode, isFalse);
    });

    test('Admin (ADM001) logs in successfully with server token and admin role',
        () async {
      final repo = AuthRepositoryImpl(
        apiService: AuthApiService(staticRahulMockClient),
        dioClient: staticRahulMockClient,
        preferences: prefs,
      );

      final session = await repo.login(
        identifier: 'admin@gmail.com',
        password: 'admin123',
      );

      expect(session.user.id, 'ADM001');
      expect(session.user.role, AppConstants.roleAdmin);
      expect(session.token, 'dummy_token_123');
      expect(session.isDemoMode, isFalse);
    });

    test('rejects incorrect password with 401 Unauthorized', () async {
      final repo = AuthRepositoryImpl(
        apiService: AuthApiService(staticRahulMockClient),
        dioClient: staticRahulMockClient,
        preferences: prefs,
      );

      await expectLater(
        repo.login(
          identifier: 'rahul@gmail.com',
          password: 'wrong_password',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue),
        ),
      );
    });

    test(
        'AttendanceModel preserves null check-in timestamp and does not create fake times',
        () {
      final rawWithoutCheckIn = {
        'id': 1,
        'employee_id': 'EMP001',
        'session_id': 'SESSION001',
        'attendance_type': 'check_in',
        'status': 'present',
        'sync_status': 'server_confirmed',
      };

      final parsed = AttendanceModel.fromMap(rawWithoutCheckIn);
      expect(parsed.employeeId, 'EMP001');
      expect(parsed.sessionId, 'SESSION001');
      expect(parsed.checkInTime, isNull);
      expect(parsed.isCheckedIn, isFalse);

      final rawWithCheckIn = {
        'id': 2,
        'employee_id': 'EMP001',
        'session_id': 'SESSION002',
        'attendance_type': 'check_in',
        'check_in_time': '2026-11-13T09:15:00Z',
        'status': 'present',
      };
      final parsedValid = AttendanceModel.fromMap(rawWithCheckIn);
      expect(parsedValid.isCheckedIn, isTrue);
      expect(parsedValid.checkInTime, DateTime.utc(2026, 11, 13, 9, 15));
    });
  });

  group('401/403 session expiration handling', () {
    test('logs out active authenticated session on protected 401 response',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final demoClient = DioClient(baseUrl: 'demo');
      final authRepo = AuthRepositoryImpl(
        apiService: AuthApiService(demoClient),
        dioClient: demoClient,
        preferences: prefs,
      );

      final protectedClient = _buildMockedDioClient(
        (_) => _jsonResponse({'message': 'Token expired'}, 401),
      );
      final authBloc = AuthenticationBloc(
        authRepository: authRepo,
        unauthorizedStream: protectedClient.unauthorizedEvents,
      );
      addTearDown(() async {
        await authBloc.close();
        protectedClient.close();
      });

      authBloc.add(
        const AuthLoginRequested(
          identifier: 'rahul@gmail.com',
          password: '123456',
        ),
      );
      await expectLater(
        authBloc.stream,
        emitsThrough(isA<AuthAuthenticated>()),
      );

      await expectLater(
        protectedClient.get<Map<String, dynamic>>('/attendance'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue),
        ),
      );

      await expectLater(
        authBloc.stream,
        emitsThrough(
          isA<AuthUnauthenticated>()
              .having((s) => s.errorMessage, 'errorMessage', 'Token expired'),
        ),
      );
    });
  });

  group('Check-in / Check-out sessionId, qrToken, and retry sync', () {
    test(
        'sends distinct check-out session_id & preserves qr_token across offline retry',
        () async {
      final captured = <_CapturedRequest>[];
      var failNextRequest = false;

      final client = _buildMockedDioClient((options) {
        final rawBody = options.data;
        final map = rawBody is Map<String, dynamic>
            ? rawBody
            : <String, dynamic>{};
        if (failNextRequest) {
          return _jsonResponse({'message': 'Temporary outage'}, 500);
        }
        captured.add(_CapturedRequest(options.method, options.path, map));
        return _jsonResponse({'success': true}, 200);
      });

      final local = _InMemoryAttendanceLocalDataSource();
      final repo = AttendanceRepositoryImpl(
        localDataSource: local,
        apiService: AttendanceApiService(client),
      );

      final checkInResult = await repo.submitCheckIn(
        employeeId: 'EMP001',
        employeeName: 'Rahul',
        sessionId: 'SES-IN-1',
        qrToken: 'CheckInToken1234',
        latitude: 12.9716,
        longitude: 77.5946,
      );
      expect(checkInResult.isServerConfirmed, isTrue);
      expect(captured.last.path, '/attendance/check-in');
      expect(captured.last.body['session_id'], 'SES-IN-1');
      expect(captured.last.body['qr_token'], 'CheckInToken1234');

      // Reusing check-in session ID for check-out is rejected
      await expectLater(
        repo.submitCheckOut(
          employeeId: 'EMP001',
          employeeName: 'Rahul',
          sessionId: 'SES-IN-1',
          qrToken: 'CheckOutToken5678',
          latitude: 12.9720,
          longitude: 77.5950,
        ),
        throwsA(isA<AttendanceRuleException>()),
      );

      // Offline check-out queues locally with check-out session & token preserved
      failNextRequest = true;
      final offlineCheckOut = await repo.submitCheckOut(
        employeeId: 'EMP001',
        employeeName: 'Rahul',
        sessionId: 'SES-OUT-2',
        qrToken: 'CheckOutToken5678',
        latitude: 12.9720,
        longitude: 77.5950,
      );
      expect(offlineCheckOut.isServerConfirmed, isFalse);
      expect(offlineCheckOut.record.sessionId, 'SES-IN-1');
      expect(offlineCheckOut.record.checkoutSessionId, 'SES-OUT-2');
      expect(offlineCheckOut.record.checkoutQrToken, 'CheckOutToken5678');

      // Retry sync sends check-out's session_id & qr_token, NOT check-in's
      failNextRequest = false;
      final retryResult = await repo.retrySyncRecord(offlineCheckOut.record);
      expect(retryResult.isServerConfirmed, isTrue);
      expect(retryResult.record.syncStatus, AppConstants.syncServerConfirmed);
      expect(captured.last.path, '/attendance/check-out');
      expect(captured.last.body['session_id'], 'SES-OUT-2');
      expect(captured.last.body['qr_token'], 'CheckOutToken5678');
    });

    test('StatusBadge displays correct labels for all attendance states', () {
      final checkedInBadge = StatusBadge.fromAttendanceStatus('checked_in');
      expect(checkedInBadge.label, 'PRESENT');

      final presentBadge = StatusBadge.fromAttendanceStatus('present');
      expect(presentBadge.label, 'PRESENT');

      final lateBadge = StatusBadge.fromAttendanceStatus('late');
      expect(lateBadge.label, 'LATE');

      final checkedOutBadge = StatusBadge.fromAttendanceStatus('checked_out');
      expect(checkedOutBadge.label, 'CHECKED OUT');

      final absentBadge = StatusBadge.fromAttendanceStatus('absent');
      expect(absentBadge.label, 'ABSENT');

      final unknownBadge = StatusBadge.fromAttendanceStatus('');
      expect(unknownBadge.label, 'ABSENT');
    });

    test('getAttendanceHistory merges local today check-in with remote history and increments present count', () async {
      final remoteHistory = [
        {
          'id': 1,
          'employee_id': 'EMP001',
          'employee_name': 'Rahul',
          'session_id': 'SES-HIST-1',
          'qr_token': 'HIST1',
          'check_in_time': '2026-11-12T09:05:00Z',
          'latitude': 12.9716,
          'longitude': 77.5946,
          'status': 'present',
          'attendance_type': 'check_in',
          'date_key': '2026-11-12',
          'sync_status': 'synced',
        }
      ];

      final client = _buildMockedDioClient((options) {
        if (options.path.contains('/attendance/history')) {
          return _jsonResponse(remoteHistory, 200);
        }
        return _jsonResponse({'success': true}, 200);
      });

      final local = _InMemoryAttendanceLocalDataSource();
      final repo = AttendanceRepositoryImpl(
        localDataSource: local,
        apiService: AttendanceApiService(client),
      );

      // Before today's check-in: 1 past record
      final initialHistory = await repo.getAttendanceHistory(employeeId: 'EMP001');
      expect(initialHistory.length, 1);

      // Submit check-in for today
      await repo.submitCheckIn(
        employeeId: 'EMP001',
        employeeName: 'Rahul',
        sessionId: 'SES-TODAY-1',
        qrToken: 'TODAY1',
        latitude: 12.9716,
        longitude: 77.5946,
      );

      // After today's check-in: merges local + remote, total count is now 2
      final updatedHistory = await repo.getAttendanceHistory(employeeId: 'EMP001');
      expect(updatedHistory.length, 2);
      expect(updatedHistory.any((r) => r.sessionId == 'SES-TODAY-1'), isTrue);
      expect(updatedHistory.any((r) => r.sessionId == 'SES-HIST-1'), isTrue);
    });

    test('AdminRepositoryImpl getDashboardOverview synchronizes remote attendance and computes accurate metrics', () async {
      final client = _buildMockedDioClient((options) {
        if (options.path == '/admin/employees') {
          return _jsonResponse([
            {'id': 'EMP001', 'name': 'Rahul', 'email': 'rahul@gmail.com', 'role': 'employee'},
            {'id': 'EMP002', 'name': 'Anjali', 'email': 'anjali@gmail.com', 'role': 'employee'},
          ], 200);
        }
        if (options.path == '/attendance') {
          final queryEmp = options.queryParameters['employee_id']?.toString() ?? '';
          if (queryEmp == 'EMP001' || options.uri.toString().contains('EMP001')) {
            return _jsonResponse({
              'data': {
                'id': 101,
                'employee_id': 'EMP001',
                'employee_name': 'Rahul',
                'session_id': 'SES-TODAY-1',
                'qr_token': 'TODAY1',
                'check_in_time': '2026-11-13T09:05:00Z',
                'latitude': 12.9716,
                'longitude': 77.5946,
                'status': 'checked_in',
                'attendance_type': 'check_in',
                'date_key': '2026-11-13',
                'sync_status': 'synced',
              }
            }, 200);
          }
          return _jsonResponse(null, 404);
        }
        return _jsonResponse([], 200);
      });

      final local = _InMemoryAttendanceLocalDataSource();
      final adminRepo = AdminRepositoryImpl(
        adminApiService: AdminApiService(client),
        qrSessionApiService: QrSessionApiService(client),
        attendanceLocalDataSource: local,
        attendanceApiService: AttendanceApiService(client),
      );

      final overview = await adminRepo.getDashboardOverview(
        date: DateTime.parse('2026-11-13T10:00:00Z'),
      );

      expect(overview.metrics.totalEmployees, 2);
      expect(overview.metrics.presentEmployees, 1);
      expect(overview.metrics.checkedInCount, 1);
      expect(overview.metrics.absentEmployees, 1);
      expect(overview.metrics.checkedOutCount, 0);

      final rahul = overview.employees.firstWhere((e) => e.employee.id == 'EMP001');
      expect(rahul.effectiveStatus, 'present');
      expect(rahul.record?.checkInTime, isNotNull);

      final anjali = overview.employees.firstWhere((e) => e.employee.id == 'EMP002');
      expect(anjali.effectiveStatus, 'absent');
      expect(anjali.record, isNull);
    });

    test('10-Step Synchronization Test: Admin note count -> Employee scans Admin QR -> Admin verifies PRESENT status, actual check-in time, and increased Present count', () async {
      final now = DateTime.now();
      final todayKey = AppDateUtils.toDateKey(now);

      final client = _buildMockedDioClient((options) {
        if (options.path == '/admin/employees') {
          return _jsonResponse([
            {'id': 'EMP001', 'name': 'Rahul', 'email': 'rahul@gmail.com', 'role': 'employee'},
            {'id': 'EMP002', 'name': 'Anjali', 'email': 'anjali@gmail.com', 'role': 'employee'},
            {'id': 'EMP003', 'name': 'Rohan', 'email': 'rohan@gmail.com', 'role': 'employee'},
          ], 200);
        }
        if (options.path == '/attendance/check-in') {
          return _jsonResponse({'success': true, 'message': 'Check-in confirmed by server'}, 200);
        }
        if (options.path == '/admin/qr-session') {
          return _jsonResponse({'success': true, 'session_id': 'SES-TEST-1', 'qr_token': 'TOKEN-TEST-1'}, 200);
        }
        return _jsonResponse([], 200);
      });

      final localDataSource = _InMemoryAttendanceLocalDataSource();
      final attendanceRepo = AttendanceRepositoryImpl(
        localDataSource: localDataSource,
        apiService: AttendanceApiService(client),
      );
      final adminRepo = AdminRepositoryImpl(
        adminApiService: AdminApiService(client),
        qrSessionApiService: QrSessionApiService(client),
        attendanceLocalDataSource: localDataSource,
        attendanceApiService: AttendanceApiService(client),
      );

      // Step 1 & 2: Login as Admin. Open Admin Dashboard and note current Present Count.
      final initialOverview = await adminRepo.getDashboardOverview(date: now);
      final initialPresentCount = initialOverview.metrics.presentEmployees;
      expect(initialPresentCount, 0);
      expect(initialOverview.metrics.absentEmployees, 3);

      // Step 3 & 4: Admin generates QR session and Employee scans valid Admin QR.
      final qrResult = await adminRepo.generateQrSession(
        attendanceType: AppConstants.typeCheckIn,
        durationMinutes: 10,
        adminId: 'ADM001',
      );

      // Step 5: Complete Check-In successfully.
      final checkInResult = await attendanceRepo.submitCheckIn(
        employeeId: 'EMP001',
        employeeName: 'Rahul',
        sessionId: qrResult.payload.sessionId,
        qrToken: qrResult.payload.qrToken,
        latitude: 12.9716,
        longitude: 77.5946,
      );
      expect(checkInResult.record.checkInTime, isNotNull);
      expect(checkInResult.record.dateKey, todayKey);

      // Step 6: Return to Admin Dashboard.
      final updatedOverview = await adminRepo.getDashboardOverview(date: now);

      // Step 7: Verify employee appears as PRESENT (or LATE arrival if tested after work cutoff).
      final rahul = updatedOverview.employees.firstWhere((e) => e.employee.id == 'EMP001');
      expect(rahul.isPresentOrCompleted, isTrue);
      expect(rahul.effectiveStatus, isIn(['present', 'late']));
      expect(StatusBadge.fromAttendanceStatus(rahul.effectiveStatus).label, isIn(['PRESENT', 'LATE']));

      // Step 8: Verify actual Check-In time.
      expect(rahul.record!.checkInTime, checkInResult.record.checkInTime);
      expect(rahul.record!.dateKey, todayKey);

      // Step 9: Verify Present Count increases correctly.
      expect(updatedOverview.metrics.presentEmployees, initialPresentCount + 1);
      expect(updatedOverview.metrics.absentEmployees, initialOverview.metrics.absentEmployees - 1);

      // Step 10: Restart application and verify persistence.
      final restartAdminRepo = AdminRepositoryImpl(
        adminApiService: AdminApiService(client),
        qrSessionApiService: QrSessionApiService(client),
        attendanceLocalDataSource: localDataSource,
        attendanceApiService: AttendanceApiService(client),
      );
      final persistedOverview = await restartAdminRepo.getDashboardOverview(date: now);
      expect(persistedOverview.metrics.presentEmployees, 1);
      final persistedRahul = persistedOverview.employees.firstWhere((e) => e.employee.id == 'EMP001');
      expect(persistedRahul.isPresentOrCompleted, isTrue);
      expect(persistedRahul.effectiveStatus, isIn(['present', 'late']));
      expect(persistedRahul.record!.checkInTime, checkInResult.record.checkInTime);
    });

    test('Full End-to-End Check-In and Check-Out lifecycle verifies exact 2-employee metric transitions', () async {
      final now = DateTime.now();

      final client = _buildMockedDioClient((options) {
        if (options.path == '/admin/employees') {
          return _jsonResponse([
            {'id': 'EMP001', 'name': 'Rahul', 'email': 'rahul@gmail.com', 'role': 'employee'},
            {'id': 'EMP002', 'name': 'Anjali', 'email': 'anjali@gmail.com', 'role': 'employee'},
          ], 200);
        }
        if (options.path == '/attendance/check-in') {
          return _jsonResponse({'success': true, 'message': 'Check-in confirmed by server'}, 200);
        }
        if (options.path == '/attendance/check-out') {
          return _jsonResponse({'success': true, 'message': 'Check-out confirmed by server'}, 200);
        }
        if (options.path == '/admin/qr-session') {
          return _jsonResponse({'success': true, 'session_id': 'SES-LIFECYCLE-1', 'qr_token': 'TOKEN-1'}, 200);
        }
        return _jsonResponse([], 200);
      });

      final localDataSource = _InMemoryAttendanceLocalDataSource();
      final attendanceRepo = AttendanceRepositoryImpl(
        localDataSource: localDataSource,
        apiService: AttendanceApiService(client),
      );
      final adminRepo = AdminRepositoryImpl(
        adminApiService: AdminApiService(client),
        qrSessionApiService: QrSessionApiService(client),
        attendanceLocalDataSource: localDataSource,
        attendanceApiService: AttendanceApiService(client),
      );

      // 1. Initial State: 2 employees, 0 checked in
      final initialOverview = await adminRepo.getDashboardOverview(date: now);
      expect(initialOverview.metrics.totalEmployees, 2);
      expect(initialOverview.metrics.presentEmployees, 0);
      expect(initialOverview.metrics.absentEmployees, 2);
      expect(initialOverview.metrics.checkedInCount, 0);
      expect(initialOverview.metrics.checkedOutCount, 0);

      // 2. Admin generates Check-In QR Session
      final checkInQr = await adminRepo.generateQrSession(
        attendanceType: AppConstants.typeCheckIn,
        durationMinutes: 10,
        adminId: 'ADM001',
      );

      // 3. Employee Rahul (EMP001) scans Check-In QR
      final checkInResult = await attendanceRepo.submitCheckIn(
        employeeId: 'EMP001',
        employeeName: 'Rahul',
        sessionId: checkInQr.payload.sessionId,
        qrToken: checkInQr.payload.qrToken,
        latitude: 12.9716,
        longitude: 77.5946,
      );
      expect(checkInResult.record.checkInTime, isNotNull);
      expect(checkInResult.record.checkOutTime, isNull);

      // 4. Expected after one real employee checks in:
      // Total: 2, Present: 1, Absent: 1, Currently Checked-In: 1, Checked-Out: 0
      final afterCheckInOverview = await adminRepo.getDashboardOverview(date: now);
      expect(afterCheckInOverview.metrics.totalEmployees, 2);
      expect(afterCheckInOverview.metrics.presentEmployees, 1);
      expect(afterCheckInOverview.metrics.absentEmployees, 1);
      expect(afterCheckInOverview.metrics.checkedInCount, 1);
      expect(afterCheckInOverview.metrics.checkedOutCount, 0);

      // 5. Admin generates Check-Out QR Session
      final checkOutQr = await adminRepo.generateQrSession(
        attendanceType: AppConstants.typeCheckOut,
        durationMinutes: 10,
        adminId: 'ADM001',
      );

      // 6. Employee Rahul (EMP001) scans Check-Out QR
      final checkOutResult = await attendanceRepo.submitCheckOut(
        employeeId: 'EMP001',
        employeeName: 'Rahul',
        sessionId: checkOutQr.payload.sessionId,
        qrToken: checkOutQr.payload.qrToken,
        latitude: 12.9718,
        longitude: 77.5948,
      );
      expect(checkOutResult.record.checkOutTime, isNotNull);

      // 7. Expected after Check-Out:
      // Total: 2, Present: 1, Absent: 1, Currently Checked-In: 0, Checked-Out: 1
      final afterCheckOutOverview = await adminRepo.getDashboardOverview(date: now);
      expect(afterCheckOutOverview.metrics.totalEmployees, 2);
      expect(afterCheckOutOverview.metrics.presentEmployees, 1);
      expect(afterCheckOutOverview.metrics.absentEmployees, 1);
      expect(afterCheckOutOverview.metrics.checkedInCount, 0);
      expect(afterCheckOutOverview.metrics.checkedOutCount, 1);
    });
  });
}

