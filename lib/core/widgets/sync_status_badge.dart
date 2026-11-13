import 'package:flutter/material.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';

/// Pill badge for attendance statuses (Present, Late, Absent, Checked Out).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.icon,
  });

  factory StatusBadge.fromAttendanceStatus(String status) {
    switch (status.toLowerCase().trim()) {
      case 'checked_in':
      case 'check_in':
      case 'in':
      case AppConstants.statusPresent:
        return const StatusBadge(
          label: 'PRESENT',
          color: AppColors.accentEmeraldDark,
          backgroundColor: AppColors.accentEmeraldSoft,
          icon: Icons.check_circle_rounded,
        );
      case AppConstants.statusLate:
        return const StatusBadge(
          label: 'LATE',
          color: AppColors.warningDark,
          backgroundColor: AppColors.warningSoft,
          icon: Icons.schedule_rounded,
        );
      case 'checked_out':
      case 'check_out':
      case 'out':
      case 'completed':
        return const StatusBadge(
          label: 'CHECKED OUT',
          color: AppColors.secondaryBlue,
          backgroundColor: AppColors.secondaryBlueSoft,
          icon: Icons.task_alt_rounded,
        );
      case AppConstants.statusAbsent:
      default:
        return const StatusBadge(
          label: 'ABSENT',
          color: AppColors.errorDark,
          backgroundColor: AppColors.errorSoft,
          icon: Icons.radio_button_unchecked_rounded,
        );
    }
  }

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clearly distinguishes server-confirmed records from locally persisted records.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({
    super.key,
    required this.syncStatus,
    this.onRetryTap,
  });

  final String syncStatus;
  final VoidCallback? onRetryTap;

  bool get isSynced => syncStatus == AppConstants.syncServerConfirmed;

  @override
  Widget build(BuildContext context) {
    final fg = isSynced ? AppColors.accentEmeraldDark : AppColors.warningDark;
    final bg = isSynced ? AppColors.successSoft : AppColors.warningSoft;
    final icon = isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded;
    final text = isSynced ? 'Server Confirmed' : 'Local Only (Pending Sync)';

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTypography.labelSmall.copyWith(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isSynced && onRetryTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.refresh_rounded, size: 13, color: fg),
          ],
        ],
      ),
    );

    if (!isSynced && onRetryTap != null) {
      return InkWell(
        onTap: onRetryTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: badge,
      );
    }
    return badge;
  }
}

