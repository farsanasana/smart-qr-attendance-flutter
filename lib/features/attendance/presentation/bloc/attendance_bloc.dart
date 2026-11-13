import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';
import 'package:newwone/features/attendance/domain/repositories/attendance_repository.dart';

// --- Events ---
abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

class AttendanceHistoryRequested extends AttendanceEvent {
  const AttendanceHistoryRequested({
    required this.employeeId,
    this.filter,
    this.customDate,
  });

  final String employeeId;
  final AttendanceDateFilter? filter;
  final DateTime? customDate;

  @override
  List<Object?> get props => [employeeId, filter, customDate];
}

class AttendanceRetryRecordSync extends AttendanceEvent {
  const AttendanceRetryRecordSync({
    required this.employeeId,
    required this.record,
  });

  final String employeeId;
  final AttendanceEntity record;

  @override
  List<Object?> get props => [employeeId, record];
}

class AttendanceSyncAllRequested extends AttendanceEvent {
  const AttendanceSyncAllRequested({required this.employeeId});

  final String employeeId;

  @override
  List<Object?> get props => [employeeId];
}

// --- States ---
abstract class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {
  const AttendanceInitial();
}

class AttendanceLoading extends AttendanceState {
  const AttendanceLoading();
}

class AttendanceLoaded extends AttendanceState {
  const AttendanceLoaded({
    required this.records,
    required this.filter,
    required this.pendingCount,
    this.customDate,
    this.isSyncing = false,
    this.feedbackMessage,
    this.isFeedbackError = false,
  });

  final List<AttendanceEntity> records;
  final AttendanceDateFilter filter;
  final DateTime? customDate;
  final int pendingCount;
  final bool isSyncing;
  final String? feedbackMessage;
  final bool isFeedbackError;

  AttendanceLoaded copyWith({
    List<AttendanceEntity>? records,
    AttendanceDateFilter? filter,
    DateTime? customDate,
    int? pendingCount,
    bool? isSyncing,
    String? feedbackMessage,
    bool? isFeedbackError,
    bool clearFeedback = false,
  }) {
    return AttendanceLoaded(
      records: records ?? this.records,
      filter: filter ?? this.filter,
      customDate: customDate ?? this.customDate,
      pendingCount: pendingCount ?? this.pendingCount,
      isSyncing: isSyncing ?? this.isSyncing,
      feedbackMessage:
          clearFeedback ? null : (feedbackMessage ?? this.feedbackMessage),
      isFeedbackError:
          clearFeedback ? false : (isFeedbackError ?? this.isFeedbackError),
    );
  }

  @override
  List<Object?> get props => [
        records,
        filter,
        customDate,
        pendingCount,
        isSyncing,
        feedbackMessage,
        isFeedbackError,
      ];
}

class AttendanceError extends AttendanceState {
  const AttendanceError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  AttendanceBloc({required AttendanceRepository attendanceRepository})
      : _repository = attendanceRepository,
        super(const AttendanceInitial()) {
    on<AttendanceHistoryRequested>(_onHistoryRequested);
    on<AttendanceRetryRecordSync>(_onRetryRecord);
    on<AttendanceSyncAllRequested>(_onSyncAll);
  }

  final AttendanceRepository _repository;

  AttendanceDateFilter _activeFilter = AttendanceDateFilter.all;
  DateTime? _activeCustomDate;

  Future<void> _onHistoryRequested(
    AttendanceHistoryRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    _activeFilter = event.filter ?? _activeFilter;
    if (event.customDate != null) {
      _activeCustomDate = event.customDate;
    }

    emit(const AttendanceLoading());
    try {
      final records = await _repository.getAttendanceHistory(
        employeeId: event.employeeId,
        filter: _activeFilter,
        customDate: _activeCustomDate,
      );
      final pendingCount = await _repository.getPendingCount(event.employeeId);
      emit(
        AttendanceLoaded(
          records: records,
          filter: _activeFilter,
          customDate: _activeCustomDate,
          pendingCount: pendingCount,
        ),
      );
    } catch (e) {
      emit(AttendanceError('Failed to load attendance history: $e'));
    }
  }

  Future<void> _onRetryRecord(
    AttendanceRetryRecordSync event,
    Emitter<AttendanceState> emit,
  ) async {
    final current = state;
    if (current is AttendanceLoaded) {
      emit(current.copyWith(isSyncing: true, clearFeedback: true));
    }
    try {
      final result = await _repository.retrySyncRecord(event.record);
      final records = await _repository.getAttendanceHistory(
        employeeId: event.employeeId,
        filter: _activeFilter,
        customDate: _activeCustomDate,
      );
      final pendingCount = await _repository.getPendingCount(event.employeeId);
      emit(
        AttendanceLoaded(
          records: records,
          filter: _activeFilter,
          customDate: _activeCustomDate,
          pendingCount: pendingCount,
          isSyncing: false,
          feedbackMessage: result.isServerConfirmed
              ? 'Attendance record synced with server.'
              : (result.warningMessage ??
                  'Unable to reach server. Record preserved locally.'),
          isFeedbackError: !result.isServerConfirmed,
        ),
      );
    } catch (e) {
      emit(AttendanceError('Sync failed: $e'));
    }
  }

  Future<void> _onSyncAll(
    AttendanceSyncAllRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    final current = state;
    if (current is AttendanceLoaded) {
      emit(current.copyWith(isSyncing: true, clearFeedback: true));
    }
    try {
      final synced = await _repository.syncAllPending(event.employeeId);
      final records = await _repository.getAttendanceHistory(
        employeeId: event.employeeId,
        filter: _activeFilter,
        customDate: _activeCustomDate,
      );
      final pendingCount = await _repository.getPendingCount(event.employeeId);
      final firstSyncError = records
          .where((r) => !r.isServerConfirmed && r.syncError != null)
          .map((r) => r.syncError!)
          .firstOrNull;
      emit(
        AttendanceLoaded(
          records: records,
          filter: _activeFilter,
          customDate: _activeCustomDate,
          pendingCount: pendingCount,
          isSyncing: false,
          feedbackMessage: synced > 0
              ? 'Synced $synced attendance record(s) with server.'
              : (firstSyncError ??
                  'Server unavailable or mock URL unconfigured. Records remain safely saved locally.'),
          isFeedbackError: synced == 0 && pendingCount > 0,
        ),
      );
    } catch (e) {
      emit(AttendanceError('Batch sync failed: $e'));
    }
  }
}

