import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:newwone/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:newwone/features/attendance/presentation/pages/attendance_history_page.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:newwone/features/dashboard/presentation/bloc/clock_cubit.dart';
import 'package:newwone/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:newwone/features/dashboard/presentation/pages/employee_dashboard_page.dart';
import 'package:newwone/features/profile/presentation/pages/employee_profile_page.dart';
import 'package:newwone/features/qr_scanner/data/services/location_service.dart';
import 'package:newwone/features/qr_scanner/presentation/bloc/qr_scanner_bloc.dart';
import 'package:newwone/features/qr_scanner/presentation/pages/qr_scanner_page.dart';

/// Main Employee Shell hosting Dashboard, QR Scanner, History, and Profile tabs.
class EmployeeShellPage extends StatelessWidget {
  const EmployeeShellPage({
    super.key,
    required this.user,
    required this.isDemoMode,
  });

  final UserEntity user;
  final bool isDemoMode;

  static const _navItems = [
    AppNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    AppNavItem(
      label: 'Scan QR',
      icon: Icons.qr_code_scanner_outlined,
      activeIcon: Icons.qr_code_scanner_rounded,
    ),
    AppNavItem(
      label: 'History',
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
    ),
    AppNavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final attendanceRepo = context.read<AttendanceRepository>();
    final locationService = context.read<LocationService>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EmployeeNavCubit()),
        BlocProvider(create: (_) => ClockCubit()),
        BlocProvider(
          create: (_) => DashboardBloc(attendanceRepository: attendanceRepo)
            ..add(DashboardLoadRequested(user.id)),
        ),
        BlocProvider(
          create: (_) => AttendanceBloc(attendanceRepository: attendanceRepo),
        ),
        BlocProvider(
          create: (_) => QRScannerBloc(
            attendanceRepository: attendanceRepo,
            locationService: locationService,
          ),
        ),
      ],
      child: BlocBuilder<EmployeeNavCubit, int>(
        builder: (context, currentIndex) {
          return Scaffold(
            body: IndexedStack(
              index: currentIndex,
              children: [
                EmployeeDashboardPage(
                  user: user,
                  onScanQrTap: () =>
                      context.read<EmployeeNavCubit>().selectTab(1),
                  onViewHistoryTap: () =>
                      context.read<EmployeeNavCubit>().selectTab(2),
                ),
                currentIndex == 1
                    ? QRScannerPage(
                        user: user,
                        onAttendanceRecorded: () {
                          context
                              .read<DashboardBloc>()
                              .add(DashboardLoadRequested(user.id));
                          context.read<AttendanceBloc>().add(
                                AttendanceHistoryRequested(employeeId: user.id),
                              );
                        },
                        onViewDashboardTap: () {
                          context.read<EmployeeNavCubit>().selectTab(0);
                          context
                              .read<DashboardBloc>()
                              .add(DashboardLoadRequested(user.id));
                        },
                      )
                    : const SizedBox.shrink(),
                AttendanceHistoryPage(employeeId: user.id),
                EmployeeProfilePage(user: user, isDemoMode: isDemoMode),
              ],
            ),
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: currentIndex,
              items: _navItems,
              onTap: (index) {
                context.read<EmployeeNavCubit>().selectTab(index);
                if (index == 0) {
                  context
                      .read<DashboardBloc>()
                      .add(DashboardLoadRequested(user.id));
                } else if (index == 2) {
                  context
                      .read<AttendanceBloc>()
                      .add(AttendanceHistoryRequested(employeeId: user.id));
                }
              },
            ),
          );
        },
      ),
    );
  }
}

