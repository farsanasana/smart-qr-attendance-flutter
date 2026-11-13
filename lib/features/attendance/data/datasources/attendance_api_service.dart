import 'package:flutter/foundation.dart';
import 'package:newwone/core/config/api_config.dart';
import 'package:newwone/core/network/api_exception.dart';
import 'package:newwone/core/network/dio_client.dart';
import 'package:newwone/features/attendance/data/models/attendance_model.dart';

/// REST API service for employee attendance endpoints.
class AttendanceApiService {
  const AttendanceApiService(this._client);

  final DioClient _client;

  /// `GET /attendance`
  Future<AttendanceModel?> getTodayAttendance(String employeeId) async {
    final normId = employeeId.trim().toUpperCase();
    try {
      final response = await _client.get<dynamic>(
        ApiConfig.attendanceEndpoint,
        queryParameters: {'employee_id': employeeId},
      );
      final body = response.data;
      if (body == null) return null;
      if (body is Map<String, dynamic>) {
        final data = body['data'] ??
            body['attendance'] ??
            (body.containsKey('id') || body.containsKey('employee_id')
                ? body
                : null);
        if (data is Map<String, dynamic>) {
          final model = AttendanceModel.fromMap(data);
          // Strictly verify that the returned attendance record belongs to the requested employee
          if (model.employeeId.toUpperCase().trim() != normId) {
            debugPrint(
              '[ATTENDANCE_DEBUG][AttendanceApi] Discarded mismatched record: '
              'requested=$employeeId, returned=${model.employeeId}',
            );
            return null;
          }
          // Reject records without a valid real timestamp (e.g. static POST check-in mock responses)
          if (model.checkInTime == null) {
            debugPrint(
              '[ATTENDANCE_DEBUG][AttendanceApi] Discarded record without valid timestamp: '
              'employeeId=${model.employeeId}, message=${body['message']}',
            );
            return null;
          }
          return model;
        }
      }
    } on ApiException catch (e) {
      debugPrint(
        '[ATTENDANCE_DEBUG][AttendanceApi] getTodayAttendance notice for $employeeId: ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint(
        '[ATTENDANCE_DEBUG][AttendanceApi] getTodayAttendance error for $employeeId: $e',
      );
      return null;
    }
    return null;
  }

  /// `POST /attendance/check-in`
  Future<Map<String, dynamic>> checkIn(
    AttendanceModel record, {
    String? qrToken,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.checkInEndpoint,
      data: record.toCheckInApiPayload(qrToken: qrToken),
    );
    return response.data ?? <String, dynamic>{};
  }

  /// `POST /attendance/check-out`
  Future<Map<String, dynamic>> checkOut(
    AttendanceModel record, {
    String? qrToken,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.checkOutEndpoint,
      data: record.toCheckOutApiPayload(qrToken: qrToken),
    );
    return response.data ?? <String, dynamic>{};
  }

  /// `GET /attendance/history`
  Future<List<AttendanceModel>> getHistory(String employeeId) async {
    final response = await _client.get<dynamic>(
      ApiConfig.attendanceHistoryEndpoint,
      queryParameters: {'employee_id': employeeId},
    );
    final body = response.data;
    if (body == null) return [];
    if (body is List) {
      return body
          .whereType<Map<String, dynamic>>()
          .map(AttendanceModel.fromMap)
          .toList();
    }
    if (body is Map<String, dynamic>) {
      final list = body['data'] ?? body['history'] ?? body['records'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(AttendanceModel.fromMap)
            .toList();
      }
    }
    return [];
  }
}

