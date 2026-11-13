import 'package:equatable/equatable.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';

/// Combined employee directory entry + attendance record for a selected date.
class EmployeeAttendanceSummary extends Equatable {
  const EmployeeAttendanceSummary({
    required this.employee,
    required this.record,
    required this.history,
  });

  final UserEntity employee;
  final AttendanceEntity? record;
  final List<AttendanceEntity> history;

  String get effectiveStatus {
    if (record == null || !record!.isCheckedIn) return AppConstants.statusAbsent;
    if (record!.isCheckedOut) return AppConstants.statusCheckedOut;
    if (record!.status == AppConstants.statusLate) return AppConstants.statusLate;
    return AppConstants.statusPresent;
  }

  bool get isPresentOrCompleted =>
      record != null && record!.checkInTime != null;

  bool get isLate => record?.status == AppConstants.statusLate;

  @override
  List<Object?> get props => [employee, record, history];
}

/// Aggregated KPI metrics for the Admin Overview Dashboard.
class AdminDashboardMetrics extends Equatable {
  const AdminDashboardMetrics({
    required this.totalEmployees,
    required this.presentEmployees,
    required this.absentEmployees,
    required this.lateArrivals,
    required this.checkedOutCount,
    this.checkedInCount = 0,
  });

  final int totalEmployees;
  final int presentEmployees;
  final int absentEmployees;
  final int lateArrivals;
  final int checkedOutCount;
  final int checkedInCount;

  double get attendanceRate =>
      totalEmployees == 0 ? 0 : (presentEmployees / totalEmployees) * 100;

  @override
  List<Object?> get props => [
        totalEmployees,
        presentEmployees,
        absentEmployees,
        lateArrivals,
        checkedOutCount,
        checkedInCount,
      ];
}

