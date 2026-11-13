import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:newwone/features/dashboard/presentation/bloc/clock_cubit.dart';
import 'package:newwone/features/dashboard/presentation/bloc/dashboard_bloc.dart';

/// Employee home dashboard displaying live clock, today's status, KPI summary,
/// quick QR scan CTA, and recent attendance activity.
class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({
    super.key,
    required this.user,
    required this.onScanQrTap,
    required this.onViewHistoryTap,
  });

  final UserEntity user;
  final VoidCallback onScanQrTap;
  final VoidCallback onViewHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<DashboardBloc>().add(DashboardLoadRequested(user.id));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeaderSliver(),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: BlocBuilder<DashboardBloc, DashboardState>(
                  builder: (context, state) {
                    if (state is DashboardInitial ||
                        state is DashboardLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                        child: AppLoadingIndicator(
                          message: 'Loading your attendance workspace...',
                        ),
                      );
                    }
                    if (state is DashboardError) {
                      return AppErrorState(
                        title: 'Dashboard Error',
                        message: state.message,
                        onRetry: () => context
                            .read<DashboardBloc>()
                            .add(DashboardLoadRequested(user.id)),
                      );
                    }

                    final loaded = state as DashboardLoaded;
                    final today = loaded.todayAttendance;
                    final String todayStatus;
                    if (today == null || !today.isCheckedIn) {
                      todayStatus = AppConstants.statusAbsent;
                    } else if (today.isCheckedOut) {
                      todayStatus = AppConstants.statusCheckedOut;
                    } else if (today.status == AppConstants.statusLate) {
                      todayStatus = AppConstants.statusLate;
                    } else {
                      todayStatus = 'checked_in';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _QuickScanActionBanner(
                          hasCheckedIn: today?.isCheckedIn ?? false,
                          hasCheckedOut: today?.isCheckedOut ?? false,
                          onTap: onScanQrTap,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          "Today's Attendance",
                          style: AppTypography.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AttendanceStatusCard(
                          dateLabel: AppDateUtils.formatFullDate(
                            DateTime.now(),
                          ),
                          status: todayStatus,
                          checkInTime: today?.checkInTime,
                          checkOutTime: today?.checkOutTime,
                          workingDuration: today?.workingDuration,
                          latitude: today?.latitude,
                          longitude: today?.longitude,
                          syncStatus: today?.syncStatus,
                          sessionId: today?.sessionId,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Attendance Summary',
                          style: AppTypography.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                            mainAxisExtent:
                                StatCard.responsiveGridExtent(context),
                          ),
                          children: [
                            StatCard(
                              title: 'Days Present',
                              value: '${loaded.totalPresentDays}',
                              icon: Icons.event_available_rounded,
                              accentColor: AppColors.accentEmerald,
                              subtitle: 'Recorded',
                            ),
                            StatCard(
                              title: 'Total Hours',
                              value: AppDateUtils.formatDuration(
                                loaded.totalWorkingHours,
                              ),
                              icon: Icons.access_time_filled_rounded,
                              accentColor: AppColors.secondaryBlue,
                              subtitle: 'Tracked',
                            ),
                            StatCard(
                              title: 'Late Arrivals',
                              value: '${loaded.lateDays}',
                              icon: Icons.schedule_rounded,
                              accentColor: AppColors.warning,
                              subtitle: 'After 9:30 AM',
                            ),
                            StatCard(
                              title: 'Pending Sync',
                              value: '${loaded.pendingSyncCount}',
                              icon: Icons.cloud_sync_rounded,
                              accentColor: loaded.pendingSyncCount > 0
                                  ? AppColors.warningDark
                                  : AppColors.accentEmerald,
                              subtitle: loaded.pendingSyncCount > 0
                                  ? 'Local Only'
                                  : 'All Synced',
                              onTap: onViewHistoryTap,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Recent Activity',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: onViewHistoryTap,
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (loaded.recentRecords.isEmpty)
                          const AppEmptyState(
                            icon: Icons.qr_code_2_rounded,
                            title: 'No Recent Activity',
                            message:
                                'Use Scan QR above to check in and start logging your attendance.',
                          )
                        else
                          ...loaded.recentRecords.map(
                            (record) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: AttendanceStatusCard(
                                dateLabel:
                                    AppDateUtils.formatDateKey(record.dateKey),
                                status: record.status,
                                checkInTime: record.checkInTime,
                                checkOutTime: record.checkOutTime,
                                workingDuration: record.workingDuration,
                                latitude: record.latitude,
                                longitude: record.longitude,
                                syncStatus: record.syncStatus,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSliver() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.navyHeaderGradient,
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.displayLarge.copyWith(
                            fontSize: 24,
                            color: AppColors.textOnDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.badge_rounded,
                          size: 15,
                          color: AppColors.accentEmerald,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user.id,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textOnDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              BlocBuilder<ClockCubit, DateTime>(
                builder: (context, now) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                size: 18,
                                color: AppColors.accentEmerald,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  AppDateUtils.formatFullDate(now),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textOnDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          AppDateUtils.formatTimeWithSeconds(now),
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.accentEmerald,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickScanActionBanner extends StatelessWidget {
  const _QuickScanActionBanner({
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    required this.onTap,
  });

  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    final Gradient gradient;

    if (!hasCheckedIn) {
      title = 'Ready to Check In';
      subtitle = 'Scan your Admin Check-In QR code with GPS verification';
      gradient = AppColors.blueActionGradient;
    } else if (!hasCheckedOut) {
      title = 'Shift In Progress';
      subtitle = 'Scan an Admin Check-Out QR code when ending your shift';
      gradient = AppColors.emeraldGradient;
    } else {
      title = 'Shift Completed Today';
      subtitle = 'Your check-in & check-out are recorded for today';
      gradient = AppColors.navyHeaderGradient;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppSpacing.elevatedShadow,
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 28,
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textOnDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.textOnDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

