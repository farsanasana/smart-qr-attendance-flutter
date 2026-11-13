import 'package:newwone/features/admin/domain/entities/employee_attendance_summary.dart';
import 'package:newwone/features/qr_scanner/domain/entities/qr_payload.dart';

class QrSessionGenerationResult {
  const QrSessionGenerationResult({
    required this.payload,
    required this.isServerConfirmed,
    this.warningMessage,
  });

  final QrPayload payload;
  final bool isServerConfirmed;
  final String? warningMessage;
}

class AdminOverviewData {
  const AdminOverviewData({
    required this.metrics,
    required this.employees,
    required this.isFromRemoteServer,
  });

  final AdminDashboardMetrics metrics;
  final List<EmployeeAttendanceSummary> employees;
  final bool isFromRemoteServer;
}

abstract class AdminRepository {
  Future<AdminOverviewData> getDashboardOverview({
    required DateTime date,
  });

  Future<QrSessionGenerationResult> generateQrSession({
    required String attendanceType,
    required int durationMinutes,
    required String adminId,
  });
}

