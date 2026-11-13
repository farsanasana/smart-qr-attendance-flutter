import 'package:flutter/material.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/core/widgets/sync_status_badge.dart';

/// Reusable attendance status card showing check-in, check-out, working hours,
/// GPS coordinates, and explicit sync status.
class AttendanceStatusCard extends StatelessWidget {
  const AttendanceStatusCard({
    super.key,
    required this.dateLabel,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.workingDuration,
    this.latitude,
    this.longitude,
    this.syncStatus,
    this.sessionId,
    this.onRetrySync,
    this.onTap,
  });

  final String dateLabel;
  final String status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final Duration? workingDuration;
  final double? latitude;
  final double? longitude;
  final String? syncStatus;
  final String? sessionId;
  final VoidCallback? onRetrySync;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = workingDuration ??
        AppDateUtils.calculateWorkingDuration(
          checkIn: checkInTime,
          checkOut: checkOutTime,
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBlueSoft,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: AppColors.secondaryBlue,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              dateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      StatusBadge.fromAttendanceStatus(status),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimeMetric(
                          label: 'CHECK IN',
                          value: checkInTime != null
                              ? AppDateUtils.formatTime(checkInTime!)
                              : '--:--',
                          icon: Icons.login_rounded,
                          iconColor: AppColors.accentEmerald,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 34,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: _TimeMetric(
                          label: 'CHECK OUT',
                          value: checkOutTime != null
                              ? AppDateUtils.formatTime(checkOutTime!)
                              : '--:--',
                          icon: Icons.logout_rounded,
                          iconColor: AppColors.secondaryBlue,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 34,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: _TimeMetric(
                          label: 'HOURS',
                          value: checkInTime != null
                              ? AppDateUtils.formatDuration(effectiveDuration)
                              : '0h 00m',
                          icon: Icons.timelapse_rounded,
                          iconColor: AppColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                if (latitude != null ||
                    longitude != null ||
                    syncStatus != null ||
                    sessionId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (latitude != null && longitude != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}',
                                style: AppTypography.labelSmall.copyWith(
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (syncStatus != null)
                        SyncStatusBadge(
                          syncStatus: syncStatus!,
                          onRetryTap:
                              syncStatus != AppConstants.syncServerConfirmed
                                  ? onRetrySync
                                  : null,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeMetric extends StatelessWidget {
  const _TimeMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLarge.copyWith(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

