import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newwone/app/app.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/network/dio_client.dart';
import 'package:newwone/features/admin/domain/entities/employee_attendance_summary.dart';
import 'package:newwone/features/admin/domain/repositories/admin_repository.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';
import 'package:newwone/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:newwone/features/auth/data/datasources/auth_api_service.dart';
import 'package:newwone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:newwone/features/qr_scanner/data/services/location_service.dart';
import 'package:newwone/features/qr_scanner/domain/entities/qr_payload.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAttendanceRepository implements AttendanceRepository {
  @override
  Future<List<AttendanceEntity>> getAttendanceHistory({
    required String employeeId,
    AttendanceDateFilter filter = AttendanceDateFilter.all,
    DateTime? customDate,
  }) async =>
      [];

  @override
  Future<int> getPendingCount(String employeeId) async => 0;

  @override
  Future<AttendanceEntity?> getTodayAttendance(String employeeId) async => null;

  @override
  Future<AttendanceWriteResult> retrySyncRecord(AttendanceEntity record) {
    throw UnimplementedError();
  }

  @override
  Future<AttendanceWriteResult> submitCheckIn({
    required String employeeId,
    required String employeeName,
    required String sessionId,
    required String qrToken,
    required double latitude,
    required double longitude,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AttendanceWriteResult> submitCheckOut({
    required String employeeId,
    required String employeeName,
    required String sessionId,
    required String qrToken,
    required double latitude,
    required double longitude,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int> syncAllPending(String employeeId) async => 0;
}

class _StubAdminRepository implements AdminRepository {
  @override
  Future<QrSessionGenerationResult> generateQrSession({
    required String attendanceType,
    required int durationMinutes,
    required String adminId,
  }) async {
    return QrSessionGenerationResult(
      payload: QrPayload(
        sessionId: 'SES-1',
        qrToken: 'Token12345678',
        attendanceType: attendanceType,
        expiresAt: DateTime.now().add(Duration(minutes: durationMinutes)),
      ),
      isServerConfirmed: false,
    );
  }

  @override
  Future<AdminOverviewData> getDashboardOverview({
    required DateTime date,
  }) async {
    return const AdminOverviewData(
      metrics: AdminDashboardMetrics(
        totalEmployees: 2,
        presentEmployees: 0,
        absentEmployees: 2,
        lateArrivals: 0,
        checkedOutCount: 0,
      ),
      employees: [],
      isFromRemoteServer: false,
    );
  }
}

void main() {
  testWidgets('Splash transitions to Login and signs in Rahul to Dashboard',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(baseUrl: 'demo');
    final authRepo = AuthRepositoryImpl(
      apiService: AuthApiService(dio),
      dioClient: dio,
      preferences: prefs,
    );

    await tester.pumpWidget(
      SmartAttendanceApp(
        authRepository: authRepo,
        attendanceRepository: _StubAttendanceRepository(),
        adminRepository: _StubAdminRepository(),
        locationService: LocationService(),
      ),
    );

    // Initially shows SplashPage
    expect(find.text(AppConstants.appName), findsOneWidget);

    // Wait for initial session check delay (900ms) + transition
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    // Now on LoginPage
    expect(find.text('Welcome to ${AppConstants.appName}'), findsOneWidget);

    // Tap empty Sign In -> validation errors appear
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    expect(find.text('Please enter your Employee ID or Email'), findsOneWidget);

    // Tap demo chip for Rahul (EMP001)
    await tester.ensureVisible(find.text('Rahul (EMP001)'));
    await tester.tap(find.text('Rahul (EMP001)'));
    await tester.pump();

    // Sign in
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Lands on Employee Dashboard
    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('EMP001'), findsOneWidget);
    expect(find.text('Ready to Check In'), findsOneWidget);

    // Verify bottom nav tabs exist
    expect(find.byIcon(Icons.qr_code_scanner_outlined), findsOneWidget);
    expect(find.byIcon(Icons.history_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
  });

  testWidgets('Admin logs in, inspects Overview, and generates a QR session',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(baseUrl: 'demo');
    final authRepo = AuthRepositoryImpl(
      apiService: AuthApiService(dio),
      dioClient: dio,
      preferences: prefs,
    );

    await tester.pumpWidget(
      SmartAttendanceApp(
        authRepository: authRepo,
        attendanceRepository: _StubAttendanceRepository(),
        adminRepository: _StubAdminRepository(),
        locationService: LocationService(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Admin (ADM001)'));
    await tester.tap(find.text('Admin (ADM001)'));
    await tester.pump();

    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Lands on Admin Overview
    expect(find.text('Attendance Console'), findsOneWidget);
    expect(find.text('Total Employees'), findsOneWidget);

    // Navigate to Generate QR tab
    await tester.tap(find.text('Generate QR'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('QR Session Generator'), findsOneWidget);
    await tester.tap(find.text('Generate QR Session'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CHECK-IN QR'), findsOneWidget);
    expect(find.text('SES-1'), findsOneWidget);
  });

  testWidgets(
      'Employee and Admin dashboards render without RenderFlex overflow on small screen and 1.3x text scale',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 680);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(baseUrl: 'demo');
    final authRepo = AuthRepositoryImpl(
      apiService: AuthApiService(dio),
      dioClient: dio,
      preferences: prefs,
    );

    await tester.pumpWidget(
      SmartAttendanceApp(
        authRepository: authRepo,
        attendanceRepository: _StubAttendanceRepository(),
        adminRepository: _StubAdminRepository(),
        locationService: LocationService(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Rahul (EMP001)'));
    await tester.tap(find.text('Rahul (EMP001)'));
    await tester.pump();
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Days Present'), findsOneWidget);
    expect(find.text('Total Hours'), findsOneWidget);
    expect(find.text('Late Arrivals'), findsOneWidget);
    expect(find.text('Pending Sync'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Navigate to History & Profile, sign out, and also verify Admin Overview overflow
    await tester.tap(find.text('History'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Attendance History'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Sign Out'));
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Sign Out'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Admin (ADM001)'));
    await tester.tap(find.text('Admin (ADM001)'));
    await tester.pump();
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Total Employees'), findsOneWidget);
    expect(find.text('Present Today'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Employees'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Employee Attendance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
