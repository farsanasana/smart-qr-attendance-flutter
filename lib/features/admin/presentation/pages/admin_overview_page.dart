import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';

/// Admin overview screen with KPI cards, attendance rate stats, and quick actions.
class AdminOverviewPage extends StatelessWidget {
  const AdminOverviewPage({
    super.key,
    required this.admin,
    required this.onGenerateQrTap,
    required this.onViewEmployeesTap,
  });

  final UserEntity admin;
  final VoidCallback onGenerateQrTap;
  final VoidCallback onViewEmployeesTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<AdminBloc>().add(const AdminDashboardRequested());
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
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
                                  'ADMIN WORKSPACE',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.accentEmerald,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Attendance Console',
                                  style: AppTypography.displayLarge.copyWith(
                                    fontSize: 24,
                                    color: AppColors.textOnDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Refresh Attendance Data',
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  color: AppColors.textOnDark,
                                  size: 22,
                                ),
                                onPressed: () => context
                                    .read<AdminBloc>()
                                    .add(const AdminDashboardRequested()),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.radiusPill),
                                ),
                                child: Text(
                                  admin.id,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textOnDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      BlocBuilder<AdminBloc, AdminState>(
                        builder: (context, state) {
                          final date = state is AdminLoaded
                              ? state.selectedDate
                              : DateTime.now();
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
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: AppColors.accentEmerald,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Flexible(
                                        child: Text(
                                          AppDateUtils.formatFullDate(date),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textOnDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: date,
                                      firstDate: DateTime(2024),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null && context.mounted) {
                                      context.read<AdminBloc>().add(
                                            AdminDashboardRequested(
                                              date: picked,
                                            ),
                                          );
                                    }
                                  },
                                  child: Text(
                                    'Change Date',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.accentEmerald,
                                    ),
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
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: BlocBuilder<AdminBloc, AdminState>(
                  builder: (context, state) {
                    if (state is AdminInitial ||
                        state is AdminLoading ||
                        (state is AdminLoaded &&
                            state.isLoadingDashboard &&
                            state.allEmployees.isEmpty)) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                        child: AppLoadingIndicator(
                          message: 'Loading workforce metrics...',
                        ),
                      );
                    }
                    if (state is AdminError) {
                      return AppErrorState(
                        title: 'Admin Console Error',
                        message: state.message,
                        onRetry: () => context
                            .read<AdminBloc>()
                            .add(const AdminDashboardRequested()),
                      );
                    }

                    final loaded = state as AdminLoaded;
                    final metrics = loaded.metrics;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AdminQuickQrBanner(onTap: onGenerateQrTap),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Workforce Overview',
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
                              title: 'Total Employees',
                              value: '${metrics.totalEmployees}',
                              icon: Icons.groups_rounded,
                              accentColor: AppColors.primaryNavy,
                              subtitle: 'Directory',
                              onTap: onViewEmployeesTap,
                            ),
                            StatCard(
                              title: 'Present Today',
                              value: '${metrics.presentEmployees}',
                              icon: Icons.check_circle_rounded,
                              accentColor: AppColors.accentEmerald,
                              subtitle:
                                  '${metrics.attendanceRate.toStringAsFixed(0)}% rate',
                            ),
                            StatCard(
                              title: 'Absent',
                              value: '${metrics.absentEmployees}',
                              icon: Icons.person_off_rounded,
                              accentColor: AppColors.error,
                              subtitle: 'Not checked in',
                            ),
                            StatCard(
                              title: 'Late Arrivals',
                              value: '${metrics.lateArrivals}',
                              icon: Icons.schedule_rounded,
                              accentColor: AppColors.warning,
                              subtitle: 'After 9:30 AM',
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _AttendanceStatisticsCard(
                          rate: metrics.attendanceRate,
                          present: metrics.presentEmployees,
                          total: metrics.totalEmployees,
                          checkedOut: metrics.checkedOutCount,
                          isFromRemote: loaded.isFromRemoteServer,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Employee Status Snapshot',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: onViewEmployeesTap,
                              child: const Text('See All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ...loaded.allEmployees.take(5).map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: EmployeeProfileCard(
                              name: item.employee.name,
                              employeeId: item.employee.id,
                              email: item.record?.checkInTime != null
                                  ? 'Date: ${AppDateUtils.formatShortDate(loaded.selectedDate)} • In: ${AppDateUtils.formatTime(item.record!.checkInTime!)}'
                                  : 'Date: ${AppDateUtils.formatShortDate(loaded.selectedDate)} • No check-in recorded',
                              role: item.employee.role,
                              department: item.employee.department,
                              trailing: StatusBadge.fromAttendanceStatus(
                                item.effectiveStatus,
                              ),
                              onTap: onViewEmployeesTap,
                            ),
                          );
                        }),
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
}

class _AdminQuickQrBanner extends StatelessWidget {
  const _AdminQuickQrBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.blueActionGradient,
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
                    Icons.qr_code_2_rounded,
                    size: 30,
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Dynamic QR Session',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textOnDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Issue time-limited Check-In or Check-Out QR codes',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.textOnDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceStatisticsCard extends StatelessWidget {
  const _AttendanceStatisticsCard({
    required this.rate,
    required this.present,
    required this.total,
    required this.checkedOut,
    required this.isFromRemote,
  });

  final double rate;
  final int present;
  final int total;
  final int checkedOut;
  final bool isFromRemote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Attendance Completion Rate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.accentEmeraldDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.surfaceSubtle,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.accentEmerald,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$present of $total employees checked in  •  $checkedOut completed checkout  •  Source: ${isFromRemote ? "Mock API + SQLite" : "Local Directory + SQLite"}',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

