import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/config/api_config.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:newwone/features/auth/presentation/bloc/authentication_bloc.dart';

/// Profile screen shared by Employee & Admin roles with logout confirmation.
class EmployeeProfilePage extends StatelessWidget {
  const EmployeeProfilePage({
    super.key,
    required this.user,
    required this.isDemoMode,
  });

  final UserEntity user;
  final bool isDemoMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(
        title: 'Profile & Account',
        subtitle: 'Identity, role, and security environment',
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmployeeProfileCard(
              name: user.name,
              employeeId: user.id,
              email: user.email,
              role: user.role,
              department: user.department,
              darkHeader: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionCard(
              title: 'Account Details',
              children: [
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'User ID',
                  value: user.id,
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Full Name',
                  value: user.name,
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email Address',
                  value: user.email,
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.work_outline_rounded,
                  label: 'Role & Department',
                  value: '${user.role.toUpperCase()} • ${user.department}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'API & Security Mode',
              children: [
                _InfoTile(
                  icon: Icons.cloud_outlined,
                  label: 'API Base URL',
                  value: ApiConfig.isMockServerConfigured
                      ? ApiConfig.baseUrl
                      : 'Placeholder (Local SQLite Demo Mode)',
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.security_rounded,
                        size: 20,
                        color: AppColors.warningDark,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          isDemoMode || !ApiConfig.isMockServerConfigured
                              ? 'Demo Mode Notice: QR payload structure and expiry are validated client-side and persisted locally in SQLite. Production deployments require backend cryptographic token verification.'
                              : 'Connected to configured Postman Mock Server endpoint via Dio.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Sign Out',
              icon: Icons.logout_rounded,
              variant: AppButtonVariant.danger,
              onPressed: () async {
                final confirmed = await AppConfirmDialog.show(
                  context,
                  title: 'Sign Out?',
                  message:
                      'Your locally saved SQLite attendance records will remain preserved on this device.',
                  confirmLabel: 'Sign Out',
                  isDestructive: true,
                  icon: Icons.logout_rounded,
                );
                if (confirmed && context.mounted) {
                  context
                      .read<AuthenticationBloc>()
                      .add(const AuthLogoutRequested());
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
          child: Text(
            title,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppSpacing.cardShadow,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondaryBlue),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyLarge.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

