import 'package:flutter/material.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';

/// Reusable employee profile card for Profile, Dashboard, and Admin views.
class EmployeeProfileCard extends StatelessWidget {
  const EmployeeProfileCard({
    super.key,
    required this.name,
    required this.employeeId,
    required this.email,
    required this.role,
    this.department = 'Corporate Operations',
    this.trailing,
    this.onTap,
    this.darkHeader = false,
  });

  final String name;
  final String employeeId;
  final String email;
  final String role;
  final String department;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool darkHeader;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'SA';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.toLowerCase() == 'admin';

    return Container(
      decoration: BoxDecoration(
        gradient: darkHeader ? AppColors.navyHeaderGradient : null,
        color: darkHeader ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: darkHeader ? null : Border.all(color: AppColors.border),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: isAdmin
                        ? AppColors.blueActionGradient
                        : AppColors.emeraldGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials,
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                color: darkHeader
                                    ? AppColors.textOnDark
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: darkHeader
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : AppColors.secondaryBlueSoft,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 10,
                                color: darkHeader
                                    ? AppColors.textOnDark
                                    : AppColors.secondaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$employeeId  •  $department',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: darkHeader
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: darkHeader
                              ? Colors.white.withValues(alpha: 0.68)
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

