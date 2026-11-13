import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/admin/domain/repositories/admin_repository.dart';
import 'package:newwone/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:newwone/features/admin/presentation/pages/admin_employees_page.dart';
import 'package:newwone/features/admin/presentation/pages/admin_overview_page.dart';
import 'package:newwone/features/admin/presentation/pages/admin_qr_generator_page.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:newwone/features/profile/presentation/pages/employee_profile_page.dart';

/// Main Admin Shell hosting Overview, QR Generator, Employees, and Profile tabs.
class AdminShellPage extends StatelessWidget {
  const AdminShellPage({
    super.key,
    required this.admin,
    required this.isDemoMode,
  });

  final UserEntity admin;
  final bool isDemoMode;

  static const _navItems = [
    AppNavItem(
      label: 'Overview',
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics_rounded,
    ),
    AppNavItem(
      label: 'Generate QR',
      icon: Icons.qr_code_2_outlined,
      activeIcon: Icons.qr_code_2_rounded,
    ),
    AppNavItem(
      label: 'Employees',
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups_rounded,
    ),
    AppNavItem(
      label: 'Profile',
      icon: Icons.admin_panel_settings_outlined,
      activeIcon: Icons.admin_panel_settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final adminRepo = context.read<AdminRepository>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AdminNavCubit()),
        BlocProvider(
          create: (_) => AdminBloc(adminRepository: adminRepo)
            ..add(const AdminDashboardRequested()),
        ),
      ],
      child: BlocBuilder<AdminNavCubit, int>(
        builder: (context, currentIndex) {
          return Scaffold(
            body: IndexedStack(
              index: currentIndex,
              children: [
                AdminOverviewPage(
                  admin: admin,
                  onGenerateQrTap: () =>
                      context.read<AdminNavCubit>().selectTab(1),
                  onViewEmployeesTap: () =>
                      context.read<AdminNavCubit>().selectTab(2),
                ),
                AdminQrGeneratorPage(admin: admin),
                const AdminEmployeesPage(),
                EmployeeProfilePage(user: admin, isDemoMode: isDemoMode),
              ],
            ),
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: currentIndex,
              items: _navItems,
              onTap: (index) {
                context.read<AdminNavCubit>().selectTab(index);
                if (index == 0 || index == 2) {
                  context
                      .read<AdminBloc>()
                      .add(const AdminDashboardRequested());
                }
              },
            ),
          );
        },
      ),
    );
  }
}

