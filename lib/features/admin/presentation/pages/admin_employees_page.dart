import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/admin/domain/entities/employee_attendance_summary.dart';
import 'package:newwone/features/admin/presentation/bloc/admin_bloc.dart';

/// Admin employee attendance directory with search, date filter, and detail sheet.
class AdminEmployeesPage extends StatefulWidget {
  const AdminEmployeesPage({super.key});

  @override
  State<AdminEmployeesPage> createState() => _AdminEmployeesPageState();
}

class _AdminEmployeesPageState extends State<AdminEmployeesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Employee Attendance',
        subtitle: 'Search, date filter & individual logs',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                context.read<AdminBloc>().add(const AdminDashboardRequested()),
          ),
        ],
      ),
      body: BlocBuilder<AdminBloc, AdminState>(
        builder: (context, state) {
          if (state is AdminInitial ||
              state is AdminLoading ||
              (state is AdminLoaded &&
                  state.isLoadingDashboard &&
                  state.allEmployees.isEmpty)) {
            return const AppLoadingIndicator(
              message: 'Loading employee attendance directory...',
            );
          }
          if (state is AdminError) {
            return AppErrorState(
              title: 'Error Loading Employees',
              message: state.message,
              onRetry: () => context
                  .read<AdminBloc>()
                  .add(const AdminDashboardRequested()),
            );
          }

          final loaded = state as AdminLoaded;

          return Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _searchController,
                            hintText: 'Search by name, ID, or email...',
                            prefixIcon: Icons.search_rounded,
                            textInputAction: TextInputAction.search,
                            onChanged: (value) => context
                                .read<AdminBloc>()
                                .add(AdminSearchQueryChanged(value)),
                            suffixIcon: loaded.searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      context.read<AdminBloc>().add(
                                            const AdminSearchQueryChanged(''),
                                          );
                                    },
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: loaded.selectedDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null && context.mounted) {
                              context
                                  .read<AdminBloc>()
                                  .add(AdminDashboardRequested(date: picked));
                            }
                          },
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBlueSoft,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                  color: AppColors.secondaryBlue,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppDateUtils.formatShortDate(
                                    loaded.selectedDate,
                                  ),
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.secondaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ('all', 'All (${loaded.allEmployees.length})'),
                          (
                            'present',
                            'Present (${loaded.metrics.presentEmployees})',
                          ),
                          (
                            'checked_out',
                            'Checked Out (${loaded.metrics.checkedOutCount})',
                          ),
                          (
                            'late',
                            'Late (${loaded.metrics.lateArrivals})',
                          ),
                          (
                            'absent',
                            'Absent (${loaded.metrics.absentEmployees})',
                          ),
                        ].map((chip) {
                          final selected = loaded.statusFilter == chip.$1;
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: ChoiceChip(
                              label: Text(chip.$2),
                              selected: selected,
                              selectedColor: AppColors.primaryNavy,
                              backgroundColor: AppColors.surfaceSubtle,
                              labelStyle: AppTypography.labelSmall.copyWith(
                                color: selected
                                    ? AppColors.textOnDark
                                    : AppColors.textSecondary,
                              ),
                              side: BorderSide.none,
                              onSelected: (_) => context
                                  .read<AdminBloc>()
                                  .add(AdminStatusFilterChanged(chip.$1)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: loaded.filteredEmployees.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.person_search_rounded,
                        title: 'No Matching Employees',
                        message:
                            'Try adjusting your search keyword, status filter, or selected date.',
                      )
                    : ListView.separated(
                        padding: AppSpacing.pagePadding,
                        itemCount: loaded.filteredEmployees.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final item = loaded.filteredEmployees[index];
                          final rec = item.record;
                          final subtitleLine = rec?.checkInTime != null
                              ? 'Date: ${AppDateUtils.formatShortDate(loaded.selectedDate)} • In: ${AppDateUtils.formatTime(rec!.checkInTime!)}'
                                  '${rec.checkOutTime != null ? ' • Out: ${AppDateUtils.formatTime(rec.checkOutTime!)}' : ''}'
                              : 'Date: ${AppDateUtils.formatShortDate(loaded.selectedDate)} • No check-in recorded';

                          return EmployeeProfileCard(
                            name: item.employee.name,
                            employeeId: item.employee.id,
                            email: subtitleLine,
                            role: item.employee.role,
                            department: item.employee.department,
                            trailing: StatusBadge.fromAttendanceStatus(
                              item.effectiveStatus,
                            ),
                            onTap: () => _showEmployeeDetails(
                              context,
                              item,
                              loaded.selectedDate,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEmployeeDetails(
    BuildContext context,
    EmployeeAttendanceSummary summary,
    DateTime selectedDate,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              EmployeeProfileCard(
                name: summary.employee.name,
                employeeId: summary.employee.id,
                email: summary.employee.email,
                role: summary.employee.role,
                department: summary.employee.department,
                darkHeader: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Attendance on ${AppDateUtils.formatShortDate(selectedDate)}',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (summary.record != null)
                AttendanceStatusCard(
                  dateLabel: AppDateUtils.formatDateKey(summary.record!.dateKey),
                  status: summary.record!.status,
                  checkInTime: summary.record!.checkInTime,
                  checkOutTime: summary.record!.checkOutTime,
                  workingDuration: summary.record!.workingDuration,
                  latitude: summary.record!.latitude,
                  longitude: summary.record!.longitude,
                  syncStatus: summary.record!.syncStatus,
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(
                    'No attendance recorded for ${AppDateUtils.formatShortDate(selectedDate)}.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.errorDark,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Recent History (${summary.history.length})',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (summary.history.isEmpty)
                Text(
                  'No historical attendance logs found in local SQLite.',
                  style: AppTypography.bodySmall,
                )
              else
                ...summary.history.take(5).map(
                      (rec) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AttendanceStatusCard(
                          dateLabel: AppDateUtils.formatDateKey(rec.dateKey),
                          status: rec.status,
                          checkInTime: rec.checkInTime,
                          checkOutTime: rec.checkOutTime,
                          workingDuration: rec.workingDuration,
                          latitude: rec.latitude,
                          longitude: rec.longitude,
                          syncStatus: rec.syncStatus,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

