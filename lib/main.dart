import 'package:flutter/material.dart';
import 'package:newwone/app/app.dart';
import 'package:newwone/core/database/app_database.dart';
import 'package:newwone/core/database/database_initializer.dart';
import 'package:newwone/core/network/dio_client.dart';
import 'package:newwone/features/admin/data/datasources/admin_api_service.dart';
import 'package:newwone/features/admin/data/datasources/qr_session_api_service.dart';
import 'package:newwone/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:newwone/features/attendance/data/datasources/attendance_api_service.dart';
import 'package:newwone/features/attendance/data/datasources/attendance_local_datasource.dart';
import 'package:newwone/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:newwone/features/auth/data/datasources/auth_api_service.dart';
import 'package:newwone/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:newwone/features/qr_scanner/data/services/location_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initAppDatabaseFactory();

  final dioClient = DioClient();
  final appDatabase = AppDatabase.instance;

  final authRepository = AuthRepositoryImpl(
    apiService: AuthApiService(dioClient),
    dioClient: dioClient,
  );

  final attendanceLocalDataSource = AttendanceLocalDataSource(
    appDatabase: appDatabase,
  );

  final attendanceApiService = AttendanceApiService(dioClient);

  final attendanceRepository = AttendanceRepositoryImpl(
    localDataSource: attendanceLocalDataSource,
    apiService: attendanceApiService,
  );

  final adminRepository = AdminRepositoryImpl(
    adminApiService: AdminApiService(dioClient),
    qrSessionApiService: QrSessionApiService(dioClient),
    attendanceLocalDataSource: attendanceLocalDataSource,
    attendanceApiService: attendanceApiService,
    appDatabase: appDatabase,
  );

  final locationService = LocationService();

  runApp(
    SmartAttendanceApp(
      authRepository: authRepository,
      attendanceRepository: attendanceRepository,
      adminRepository: adminRepository,
      locationService: locationService,
      unauthorizedStream: dioClient.unauthorizedEvents,
    ),
  );
}
