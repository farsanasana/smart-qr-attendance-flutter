import 'package:flutter_test/flutter_test.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';
import 'package:newwone/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:newwone/features/qr_scanner/data/services/location_service.dart';
import 'package:newwone/features/qr_scanner/domain/entities/qr_payload.dart';
import 'package:newwone/features/qr_scanner/presentation/bloc/qr_scanner_bloc.dart';

class _FakeAttendanceRepository implements AttendanceRepository {
  AttendanceEntity? todayRecord;
  bool serverConfirmed = false;
  int nextId = 1;

  @override
  Future<AttendanceEntity?> getTodayAttendance(String employeeId) async {
    return todayRecord;
  }

  @override
  Future<List<AttendanceEntity>> getAttendanceHistory({
    required String employeeId,
    AttendanceDateFilter filter = AttendanceDateFilter.all,
    DateTime? customDate,
  }) async {
    return todayRecord != null ? [todayRecord!] : [];
  }

  @override
  Future<int> getPendingCount(String employeeId) async =>
      todayRecord != null && !todayRecord!.isServerConfirmed ? 1 : 0;

  @override
  Future<AttendanceWriteResult> retrySyncRecord(AttendanceEntity record) async {
    todayRecord = AttendanceEntity(
      id: record.id,
      employeeId: record.employeeId,
      employeeName: record.employeeName,
      sessionId: record.sessionId,
      attendanceType: record.attendanceType,
      checkInTime: record.checkInTime,
      checkOutTime: record.checkOutTime,
      latitude: record.latitude,
      longitude: record.longitude,
      status: record.status,
      dateKey: record.dateKey,
      syncStatus: AppConstants.syncServerConfirmed,
      createdAt: record.createdAt,
    );
    return AttendanceWriteResult(
      record: todayRecord!,
      isServerConfirmed: true,
    );
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
    todayRecord = AttendanceEntity(
      id: nextId++,
      employeeId: employeeId,
      employeeName: employeeName,
      sessionId: sessionId,
      attendanceType: AppConstants.typeCheckIn,
      checkInTime: now,
      latitude: latitude,
      longitude: longitude,
      status: AppConstants.statusPresent,
      dateKey: AppDateUtils.toDateKey(now),
      syncStatus: serverConfirmed
          ? AppConstants.syncServerConfirmed
          : AppConstants.syncLocalPending,
      syncError: serverConfirmed ? null : 'Offline mode',
      createdAt: now,
    );
    return AttendanceWriteResult(
      record: todayRecord!,
      isServerConfirmed: serverConfirmed,
      warningMessage: serverConfirmed ? null : 'Offline mode',
    );
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
    todayRecord = AttendanceEntity(
      id: todayRecord!.id,
      employeeId: employeeId,
      employeeName: employeeName,
      sessionId: sessionId,
      attendanceType: AppConstants.typeCheckOut,
      checkInTime: todayRecord!.checkInTime,
      checkOutTime: now,
      latitude: todayRecord!.latitude,
      longitude: todayRecord!.longitude,
      checkoutLatitude: latitude,
      checkoutLongitude: longitude,
      status: AppConstants.statusCheckedOut,
      dateKey: todayRecord!.dateKey,
      syncStatus: serverConfirmed
          ? AppConstants.syncServerConfirmed
          : AppConstants.syncLocalPending,
      createdAt: todayRecord!.createdAt,
    );
    return AttendanceWriteResult(
      record: todayRecord!,
      isServerConfirmed: serverConfirmed,
    );
  }

  @override
  Future<int> syncAllPending(String employeeId) async => 1;
}

class _FakeLocationService extends LocationService {
  LocationFailure? failureToThrow;
  CapturedCoordinates coords = const CapturedCoordinates(
    latitude: 12.9716,
    longitude: 77.5946,
  );

  @override
  Future<CapturedCoordinates> captureCurrentLocation() async {
    if (failureToThrow != null) throw failureToThrow!;
    return coords;
  }
}

void main() {
  const user = UserEntity(
    id: 'EMP001',
    name: 'Rahul',
    email: 'rahul@gmail.com',
    role: AppConstants.roleEmployee,
  );

  late _FakeAttendanceRepository repo;
  late _FakeLocationService locationService;
  late QRScannerBloc bloc;

  setUp(() {
    repo = _FakeAttendanceRepository();
    locationService = _FakeLocationService();
    bloc = QRScannerBloc(
      attendanceRepository: repo,
      locationService: locationService,
      localTokenVerifier: (_, _) async => true,
    );
  });

  tearDown(() => bloc.close());

  String buildRawQr({
    required String type,
    required Duration expiresIn,
  }) {
    return QrPayload(
      sessionId: 'SES-TEST-001',
      qrToken: 'SecureDemoToken12345',
      attendanceType: type,
      expiresAt: DateTime.now().toUtc().add(expiresIn),
    ).toRawPayload();
  }

  test('emits invalidQr failure for malformed QR content', () async {
    bloc.add(const QrCodeDetected(rawPayload: 'bad-qr', user: user));
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<QrScannerFailure>()
            .having((s) => s.failureType, 'type', QrFailureType.invalidQr),
      ),
    );
  });

  test('emits expiredQr failure for expired QR session', () async {
    final raw = buildRawQr(
      type: AppConstants.typeCheckIn,
      expiresIn: const Duration(minutes: -2),
    );
    bloc.add(QrCodeDetected(rawPayload: raw, user: user));
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<QrScannerFailure>()
            .having((s) => s.failureType, 'type', QrFailureType.expiredQr),
      ),
    );
  });

  test('prevents check-out without an existing check-in', () async {
    final raw = buildRawQr(
      type: AppConstants.typeCheckOut,
      expiresIn: const Duration(minutes: 5),
    );
    bloc.add(QrCodeDetected(rawPayload: raw, user: user));
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<QrScannerFailure>().having(
          (s) => s.failureType,
          'type',
          QrFailureType.noCheckInForCheckOut,
        ),
      ),
    );
  });

  test('records check-in locally when offline and prevents duplicate check-in',
      () async {
    final raw = buildRawQr(
      type: AppConstants.typeCheckIn,
      expiresIn: const Duration(minutes: 5),
    );
    bloc.add(QrCodeDetected(rawPayload: raw, user: user));
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<QrScannerSuccess>()
            .having((s) => s.isServerConfirmed, 'serverConfirmed', isFalse)
            .having((s) => s.record.latitude, 'latitude', 12.9716),
      ),
    );

    // Reset to scanning and attempt duplicate check-in
    bloc.add(const QrScannerStarted());
    bloc.add(QrCodeDetected(rawPayload: raw, user: user));
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<QrScannerFailure>().having(
          (s) => s.failureType,
          'type',
          QrFailureType.duplicateCheckIn,
        ),
      ),
    );
  });

  test('emits gpsDisabled failure when GPS services are turned off', () async {
    locationService.failureToThrow = const LocationFailure(
      type: LocationFailureType.serviceDisabled,
      message: 'GPS off',
    );
    final raw = buildRawQr(
      type: AppConstants.typeCheckIn,
      expiresIn: const Duration(minutes: 5),
    );
    bloc.add(QrCodeDetected(rawPayload: raw, user: user));
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<QrScannerFailure>()
            .having((s) => s.failureType, 'type', QrFailureType.gpsDisabled),
      ),
    );
  });

  test('rejects reusing check-in session ID for check-out', () async {
    final checkInRaw = buildRawQr(
      type: AppConstants.typeCheckIn,
      expiresIn: const Duration(minutes: 5),
    );
    bloc.add(QrCodeDetected(rawPayload: checkInRaw, user: user));
    await expectLater(
      bloc.stream,
      emitsThrough(isA<QrScannerSuccess>()),
    );

    bloc.add(const QrScannerStarted());
    final replayedSessionCheckOut = QrPayload(
      sessionId: 'SES-TEST-001',
      qrToken: 'AnotherToken12345678',
      attendanceType: AppConstants.typeCheckOut,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    ).toRawPayload();
    bloc.add(QrCodeDetected(rawPayload: replayedSessionCheckOut, user: user));
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<QrScannerFailure>().having(
          (s) => s.failureType,
          'type',
          QrFailureType.duplicateCheckOut,
        ),
      ),
    );
  });
}
