import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';

/// Result returned when recording or syncing an attendance event.
class AttendanceWriteResult {
  const AttendanceWriteResult({
    required this.record,
    required this.isServerConfirmed,
    this.warningMessage,
  });

  final AttendanceEntity record;
  final bool isServerConfirmed;
  final String? warningMessage;
}

/// Filter options for employee attendance history.
enum AttendanceDateFilter { all, today, thisWeek, thisMonth, customDate }

abstract class AttendanceRepository {
  Future<AttendanceEntity?> getTodayAttendance(String employeeId);

  Future<List<AttendanceEntity>> getAttendanceHistory({
    required String employeeId,
    AttendanceDateFilter filter = AttendanceDateFilter.all,
    DateTime? customDate,
  });

  Future<AttendanceWriteResult> submitCheckIn({
    required String employeeId,
    required String employeeName,
    required String sessionId,
    required String qrToken,
    required double latitude,
    required double longitude,
  });

  Future<AttendanceWriteResult> submitCheckOut({
    required String employeeId,
    required String employeeName,
    required String sessionId,
    required String qrToken,
    required double latitude,
    required double longitude,
  });

  Future<AttendanceWriteResult> retrySyncRecord(AttendanceEntity record);

  Future<int> syncAllPending(String employeeId);

  Future<int> getPendingCount(String employeeId);
}

