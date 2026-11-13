import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';
import 'package:newwone/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:newwone/features/attendance/presentation/bloc/attendance_bloc.dart';

/// Employee Attendance History screen backed by SQLite & AttendanceBloc.
class AttendanceHistoryPage extends StatelessWidget {
  const AttendanceHistoryPage({
    super.key,
    required this.employeeId,
  });

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Attendance History',
        subtitle: 'SQLite local ledger & server sync status',
        actions: [
          BlocBuilder<AttendanceBloc, AttendanceState>(
            builder: (context, state) {
              if (state is AttendanceLoaded && state.pendingCount > 0) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: TextButton.icon(
                    onPressed: state.isSyncing
                        ? null
                        : () => context.read<AttendanceBloc>().add(
                              AttendanceSyncAllRequested(
                                employeeId: employeeId,
                              ),
                            ),
                    icon: state.isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: Text('Sync (${state.pendingCount})'),
                  ),
                );
              }
              return IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => context.read<AttendanceBloc>().add(
                      AttendanceHistoryRequested(employeeId: employeeId),
                    ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<AttendanceBloc, AttendanceState>(
        listener: (context, state) {
          if (state is AttendanceLoaded && state.feedbackMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.feedbackMessage!),
                backgroundColor: state.isFeedbackError
                    ? AppColors.warningDark
                    : AppColors.accentEmeraldDark,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AttendanceInitial || state is AttendanceLoading) {
            return const AppLoadingIndicator(
              message: 'Loading attendance records from SQLite...',
            );
          }
          if (state is AttendanceError) {
            return AppErrorState(
              title: 'Unable to Load History',
              message: state.message,
              onRetry: () => context.read<AttendanceBloc>().add(
                    AttendanceHistoryRequested(employeeId: employeeId),
                  ),
            );
          }

          final loaded = state as AttendanceLoaded;

          return Column(
            children: [
              _FilterStrip(
                employeeId: employeeId,
                activeFilter: loaded.filter,
                customDate: loaded.customDate,
              ),
              Expanded(
                child: loaded.records.isEmpty
                    ? AppEmptyState(
                        icon: Icons.event_busy_rounded,
                        title: 'No Attendance Records Found',
                        message: loaded.filter == AttendanceDateFilter.all
                            ? 'Scan a Check-In QR code to record your first attendance entry.'
                            : 'No records match the selected date filter.',
                        actionLabel: loaded.filter != AttendanceDateFilter.all
                            ? 'Show All Records'
                            : null,
                        onAction: loaded.filter != AttendanceDateFilter.all
                            ? () => context.read<AttendanceBloc>().add(
                                  AttendanceHistoryRequested(
                                    employeeId: employeeId,
                                    filter: AttendanceDateFilter.all,
                                  ),
                                )
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          context.read<AttendanceBloc>().add(
                                AttendanceHistoryRequested(
                                  employeeId: employeeId,
                                ),
                              );
                        },
                        child: ListView.separated(
                          padding: AppSpacing.pagePadding,
                          itemCount: loaded.records.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final record = loaded.records[index];
                            return AttendanceStatusCard(
                              dateLabel:
                                  AppDateUtils.formatDateKey(record.dateKey),
                              status: record.status,
                              checkInTime: record.checkInTime,
                              checkOutTime: record.checkOutTime,
                              workingDuration: record.workingDuration,
                              latitude: record.latitude,
                              longitude: record.longitude,
                              syncStatus: record.syncStatus,
                              sessionId: record.sessionId,
                              onRetrySync: () =>
                                  context.read<AttendanceBloc>().add(
                                        AttendanceRetryRecordSync(
                                          employeeId: employeeId,
                                          record: record,
                                        ),
                                      ),
                              onTap: () => _showRecordDetails(context, record),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRecordDetails(BuildContext context, AttendanceEntity record) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppDateUtils.formatDateKey(record.dateKey),
                  style: AppTypography.headlineMedium,
                ),
                StatusBadge.fromAttendanceStatus(record.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow('Check-In Session', record.sessionId),
            if (record.checkoutSessionId != null)
              _DetailRow('Check-Out Session', record.checkoutSessionId!),
            _DetailRow(
              'Check-In Time',
              record.checkInTime != null
                  ? AppDateUtils.formatTimeWithSeconds(record.checkInTime!)
                  : 'Not recorded',
            ),
            _DetailRow(
              'Check-Out Time',
              record.checkOutTime != null
                  ? AppDateUtils.formatTimeWithSeconds(record.checkOutTime!)
                  : 'Pending check-out',
            ),
            _DetailRow(
              'Working Hours',
              AppDateUtils.formatDuration(record.workingDuration),
            ),
            _DetailRow(
              'Check-In GPS',
              record.latitude != null && record.longitude != null
                  ? '${record.latitude!.toStringAsFixed(6)}, ${record.longitude!.toStringAsFixed(6)}'
                  : 'Unavailable',
            ),
            if (record.checkoutLatitude != null &&
                record.checkoutLongitude != null)
              _DetailRow(
                'Check-Out GPS',
                '${record.checkoutLatitude!.toStringAsFixed(6)}, ${record.checkoutLongitude!.toStringAsFixed(6)}',
              ),
            const SizedBox(height: AppSpacing.sm),
            SyncStatusBadge(syncStatus: record.syncStatus),
            if (record.syncError != null && !record.isServerConfirmed) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                record.syncError!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warningDark,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.labelLarge.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.employeeId,
    required this.activeFilter,
    required this.customDate,
  });

  final String employeeId;
  final AttendanceDateFilter activeFilter;
  final DateTime? customDate;

  @override
  Widget build(BuildContext context) {
    final chips = [
      (AttendanceDateFilter.all, 'All'),
      (AttendanceDateFilter.today, 'Today'),
      (AttendanceDateFilter.thisWeek, 'This Week'),
      (AttendanceDateFilter.thisMonth, 'This Month'),
    ];

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...chips.map((entry) {
              final selected = activeFilter == entry.$1;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  label: Text(entry.$2),
                  selected: selected,
                  selectedColor: AppColors.primaryNavy,
                  backgroundColor: AppColors.surfaceSubtle,
                  labelStyle: AppTypography.labelSmall.copyWith(
                    color: selected
                        ? AppColors.textOnDark
                        : AppColors.textSecondary,
                  ),
                  side: BorderSide.none,
                  onSelected: (_) => context.read<AttendanceBloc>().add(
                        AttendanceHistoryRequested(
                          employeeId: employeeId,
                          filter: entry.$1,
                        ),
                      ),
                ),
              );
            }),
            ActionChip(
              avatar: Icon(
                Icons.date_range_rounded,
                size: 16,
                color: activeFilter == AttendanceDateFilter.customDate
                    ? AppColors.textOnDark
                    : AppColors.secondaryBlue,
              ),
              label: Text(
                activeFilter == AttendanceDateFilter.customDate &&
                        customDate != null
                    ? AppDateUtils.formatShortDate(customDate!)
                    : 'Pick Date',
              ),
              backgroundColor: activeFilter == AttendanceDateFilter.customDate
                  ? AppColors.secondaryBlue
                  : AppColors.secondaryBlueSoft,
              labelStyle: AppTypography.labelSmall.copyWith(
                color: activeFilter == AttendanceDateFilter.customDate
                    ? AppColors.textOnDark
                    : AppColors.secondaryBlue,
              ),
              side: BorderSide.none,
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: customDate ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (picked != null && context.mounted) {
                  context.read<AttendanceBloc>().add(
                        AttendanceHistoryRequested(
                          employeeId: employeeId,
                          filter: AttendanceDateFilter.customDate,
                          customDate: picked,
                        ),
                      );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

