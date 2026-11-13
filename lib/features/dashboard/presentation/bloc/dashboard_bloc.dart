import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';
import 'package:newwone/features/attendance/domain/repositories/attendance_repository.dart';

// --- Events ---
abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

class DashboardLoadRequested extends DashboardEvent {
  const DashboardLoadRequested(this.employeeId);
  final String employeeId;

  @override
  List<Object?> get props => [employeeId];
}

// --- States ---
abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  const DashboardLoaded({
    required this.todayAttendance,
    required this.recentRecords,
    required this.totalPresentDays,
    required this.lateDays,
    required this.totalWorkingHours,
    required this.pendingSyncCount,
  });

  final AttendanceEntity? todayAttendance;
  final List<AttendanceEntity> recentRecords;
  final int totalPresentDays;
  final int lateDays;
  final Duration totalWorkingHours;
  final int pendingSyncCount;

  @override
  List<Object?> get props => [
        todayAttendance,
        recentRecords,
        totalPresentDays,
        lateDays,
        totalWorkingHours,
        pendingSyncCount,
      ];
}

class DashboardError extends DashboardState {
  const DashboardError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({required AttendanceRepository attendanceRepository})
      : _repository = attendanceRepository,
        super(const DashboardInitial()) {
    on<DashboardLoadRequested>(_onLoadRequested);
  }

  final AttendanceRepository _repository;

  Future<void> _onLoadRequested(
    DashboardLoadRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (state is DashboardInitial) {
      emit(const DashboardLoading());
    }

    try {
      final today = await _repository.getTodayAttendance(event.employeeId);
      final allRecords = await _repository.getAttendanceHistory(
        employeeId: event.employeeId,
        filter: AttendanceDateFilter.all,
      );
      final pendingCount = await _repository.getPendingCount(event.employeeId);

      int lateCount = 0;
      Duration totalDuration = Duration.zero;
      for (final record in allRecords) {
        if (record.status == AppConstants.statusLate) {
          lateCount++;
        }
        totalDuration += record.workingDuration;
      }

      emit(
        DashboardLoaded(
          todayAttendance: today,
          recentRecords: allRecords.take(4).toList(),
          totalPresentDays: allRecords.length,
          lateDays: lateCount,
          totalWorkingHours: totalDuration,
          pendingSyncCount: pendingCount,
        ),
      );
    } catch (e) {
      emit(DashboardError('Unable to load dashboard summary: $e'));
    }
  }
}

