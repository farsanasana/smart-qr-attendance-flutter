import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/network/api_exception.dart';
import 'package:newwone/core/theme/app_theme.dart';
import 'package:newwone/features/admin/domain/repositories/admin_repository.dart';
import 'package:newwone/features/admin/presentation/pages/admin_shell_page.dart';
import 'package:newwone/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:newwone/features/auth/domain/repositories/auth_repository.dart';
import 'package:newwone/features/auth/presentation/bloc/authentication_bloc.dart';
import 'package:newwone/features/auth/presentation/pages/login_page.dart';
import 'package:newwone/features/auth/presentation/pages/splash_page.dart';
import 'package:newwone/features/dashboard/presentation/pages/employee_shell_page.dart';
import 'package:newwone/features/qr_scanner/data/services/location_service.dart';

/// Root Smart Attendance application widget.
class SmartAttendanceApp extends StatelessWidget {
  const SmartAttendanceApp({
    super.key,
    required this.authRepository,
    required this.attendanceRepository,
    required this.adminRepository,
    required this.locationService,
    this.unauthorizedStream,
    this.triggerInitialAuthCheck = true,
  });

  final AuthRepository authRepository;
  final AttendanceRepository attendanceRepository;
  final AdminRepository adminRepository;
  final LocationService locationService;
  final Stream<ApiException>? unauthorizedStream;
  final bool triggerInitialAuthCheck;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<AttendanceRepository>.value(
          value: attendanceRepository,
        ),
        RepositoryProvider<AdminRepository>.value(value: adminRepository),
        RepositoryProvider<LocationService>.value(value: locationService),
      ],
      child: BlocProvider<AuthenticationBloc>(
        create: (_) {
          final bloc = AuthenticationBloc(
            authRepository: authRepository,
            unauthorizedStream: unauthorizedStream,
          );
          if (triggerInitialAuthCheck) {
            bloc.add(const AuthCheckRequested());
          }
          return bloc;
        },
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: BlocBuilder<AuthenticationBloc, AuthenticationState>(
            builder: (context, state) {
              final Widget screen;
              if (state is AuthInitial || state is AuthSessionChecking) {
                screen = const SplashPage(key: ValueKey('splash'));
              } else if (state is AuthAuthenticated) {
                screen = state.user.isAdmin
                    ? AdminShellPage(
                        key: ValueKey('admin-${state.user.id}'),
                        admin: state.user,
                        isDemoMode: state.isDemoMode,
                      )
                    : EmployeeShellPage(
                        key: ValueKey('employee-${state.user.id}'),
                        user: state.user,
                        isDemoMode: state.isDemoMode,
                      );
              } else {
                screen = const LoginPage(key: ValueKey('login'));
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: screen,
              );
            },
          ),
        ),
      ),
    );
  }
}

