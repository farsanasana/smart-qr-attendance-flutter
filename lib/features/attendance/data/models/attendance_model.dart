import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';

/// Serializable model for SQLite (`sqflite`) and Dio JSON payloads.
class AttendanceModel extends AttendanceEntity {
  const AttendanceModel({
    super.id,
    required super.employeeId,
    required super.employeeName,
    required super.sessionId,
    super.checkoutSessionId,
    super.qrToken,
    super.checkoutQrToken,
    required super.attendanceType,
    super.checkInTime,
    super.checkOutTime,
    super.latitude,
    super.longitude,
    super.checkoutLatitude,
    super.checkoutLongitude,
    required super.status,
    required super.dateKey,
    super.syncStatus,
    super.syncError,
    required super.createdAt,
  });

  factory AttendanceModel.fromEntity(AttendanceEntity entity) {
    return AttendanceModel(
      id: entity.id,
      employeeId: entity.employeeId,
      employeeName: entity.employeeName,
      sessionId: entity.sessionId,
      checkoutSessionId: entity.checkoutSessionId,
      qrToken: entity.qrToken,
      checkoutQrToken: entity.checkoutQrToken,
      attendanceType: entity.attendanceType,
      checkInTime: entity.checkInTime,
      checkOutTime: entity.checkOutTime,
      latitude: entity.latitude,
      longitude: entity.longitude,
      checkoutLatitude: entity.checkoutLatitude,
      checkoutLongitude: entity.checkoutLongitude,
      status: entity.status,
      dateKey: entity.dateKey,
      syncStatus: entity.syncStatus,
      syncError: entity.syncError,
      createdAt: entity.createdAt,
    );
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDt(dynamic value) {
      if (value == null) return null;
      final str = value.toString();
      if (str.isEmpty) return null;
      return DateTime.tryParse(str);
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final rawDateKey = (map['date_key'] ??
            map['date'] ??
            map['dateKey'] ??
            map['attendance_date'] ??
            '')
        .toString()
        .trim();
    final effectiveDateKey = rawDateKey.isNotEmpty
        ? rawDateKey
        : AppDateUtils.toDateKey(DateTime.now());

    final status = (map['status'] ?? AppConstants.statusPresent).toString();
    final attendanceType =
        (map['attendance_type'] ?? AppConstants.typeCheckIn).toString();

    // Strictly parse actual check-in and check-out timestamps without inventing fake times.
    final checkIn = parseDt(
      map['check_in_time'] ??
          map['checkInTime'] ??
          map['checkin_time'] ??
          map['timestamp'] ??
          map['time'],
    );

    final checkOut = parseDt(
      map['check_out_time'] ?? map['checkOutTime'] ?? map['checkout_time'],
    );
    final createdAt = parseDt(map['created_at'] ?? map['createdAt']) ??
        checkIn ??
        DateTime.now();

    return AttendanceModel(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      employeeId: (map['employee_id'] ?? '').toString(),
      employeeName: (map['employee_name'] ?? '').toString(),
      sessionId: (map['session_id'] ?? '').toString(),
      checkoutSessionId: map['checkout_session_id']?.toString(),
      qrToken: map['qr_token']?.toString(),
      checkoutQrToken: map['checkout_qr_token']?.toString(),
      attendanceType: attendanceType,
      checkInTime: checkIn,
      checkOutTime: checkOut,
      latitude: parseDouble(map['latitude']),
      longitude: parseDouble(map['longitude']),
      checkoutLatitude: parseDouble(map['checkout_latitude']),
      checkoutLongitude: parseDouble(map['checkout_longitude']),
      status: status,
      dateKey: effectiveDateKey,
      syncStatus:
          (map['sync_status'] ?? AppConstants.syncLocalPending).toString(),
      syncError: map['sync_error']?.toString(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'session_id': sessionId,
      'checkout_session_id': checkoutSessionId,
      'qr_token': qrToken,
      'checkout_qr_token': checkoutQrToken,
      'attendance_type': attendanceType,
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'checkout_latitude': checkoutLatitude,
      'checkout_longitude': checkoutLongitude,
      'status': status,
      'date_key': dateKey,
      'sync_status': syncStatus,
      'sync_error': syncError,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toCheckInApiPayload({String? qrToken}) {
    final effectiveToken = qrToken ?? this.qrToken;
    return {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'session_id': sessionId,
      if (effectiveToken != null && effectiveToken.isNotEmpty)
        'qr_token': effectiveToken,
      'attendance_type': AppConstants.typeCheckIn,
      'check_in_time': checkInTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'date': dateKey,
    };
  }

  Map<String, dynamic> toCheckOutApiPayload({String? qrToken}) {
    final effectiveToken = qrToken ?? checkoutQrToken ?? this.qrToken;
    return {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'session_id': checkoutSessionId ?? sessionId,
      if (effectiveToken != null && effectiveToken.isNotEmpty)
        'qr_token': effectiveToken,
      'attendance_type': AppConstants.typeCheckOut,
      'check_out_time': checkOutTime?.toIso8601String(),
      'latitude': checkoutLatitude ?? latitude,
      'longitude': checkoutLongitude ?? longitude,
      'status': status,
      'date': dateKey,
    };
  }

  AttendanceModel copyWith({
    int? id,
    String? sessionId,
    String? checkoutSessionId,
    String? qrToken,
    String? checkoutQrToken,
    String? attendanceType,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? latitude,
    double? longitude,
    double? checkoutLatitude,
    double? checkoutLongitude,
    String? status,
    String? syncStatus,
    String? syncError,
    bool clearSyncError = false,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      employeeId: employeeId,
      employeeName: employeeName,
      sessionId: sessionId ?? this.sessionId,
      checkoutSessionId: checkoutSessionId ?? this.checkoutSessionId,
      qrToken: qrToken ?? this.qrToken,
      checkoutQrToken: checkoutQrToken ?? this.checkoutQrToken,
      attendanceType: attendanceType ?? this.attendanceType,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      checkoutLatitude: checkoutLatitude ?? this.checkoutLatitude,
      checkoutLongitude: checkoutLongitude ?? this.checkoutLongitude,
      status: status ?? this.status,
      dateKey: dateKey,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
      createdAt: createdAt,
    );
  }
}

