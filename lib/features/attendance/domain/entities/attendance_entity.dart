import 'package:equatable/equatable.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/utils/app_date_utils.dart';

/// Domain entity representing an employee attendance entry for a workday.
class AttendanceEntity extends Equatable {
  const AttendanceEntity({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.sessionId,
    this.checkoutSessionId,
    this.qrToken,
    this.checkoutQrToken,
    required this.attendanceType,
    this.checkInTime,
    this.checkOutTime,
    this.latitude,
    this.longitude,
    this.checkoutLatitude,
    this.checkoutLongitude,
    required this.status,
    required this.dateKey,
    this.syncStatus = AppConstants.syncLocalPending,
    this.syncError,
    required this.createdAt,
  });

  final int? id;
  final String employeeId;
  final String employeeName;
  final String sessionId;
  final String? checkoutSessionId;
  final String? qrToken;
  final String? checkoutQrToken;
  final String attendanceType;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? latitude;
  final double? longitude;
  final double? checkoutLatitude;
  final double? checkoutLongitude;
  final String status;
  final String dateKey;
  final String syncStatus;
  final String? syncError;
  final DateTime createdAt;

  bool get isCheckedIn => checkInTime != null;
  bool get isCheckedOut => checkOutTime != null;
  bool get isServerConfirmed => syncStatus == AppConstants.syncServerConfirmed;

  /// Session ID associated with the latest recorded operation (check-out if present).
  String get latestSessionId => checkoutSessionId ?? sessionId;

  Duration get workingDuration => AppDateUtils.calculateWorkingDuration(
        checkIn: checkInTime,
        checkOut: checkOutTime,
      );

  @override
  List<Object?> get props => [
        id,
        employeeId,
        employeeName,
        sessionId,
        checkoutSessionId,
        qrToken,
        checkoutQrToken,
        attendanceType,
        checkInTime,
        checkOutTime,
        latitude,
        longitude,
        checkoutLatitude,
        checkoutLongitude,
        status,
        dateKey,
        syncStatus,
        syncError,
        createdAt,
      ];
}

