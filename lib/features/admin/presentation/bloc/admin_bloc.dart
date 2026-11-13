import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/sync/shared_attendance_sync_store.dart';
import 'package:newwone/features/admin/domain/entities/employee_attendance_summary.dart';
import 'package:newwone/features/admin/domain/repositories/admin_repository.dart';
import 'package:newwone/features/attendance/data/models/attendance_model.dart';
import 'package:newwone/features/qr_scanner/domain/entities/qr_payload.dart';

// --- Events ---
abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

class AdminDashboardRequested extends AdminEvent {
  const AdminDashboardRequested({this.date});
  final DateTime? date;

  @override
  List<Object?> get props => [date];
}

class AdminSearchQueryChanged extends AdminEvent {
  const AdminSearchQueryChanged(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

class AdminStatusFilterChanged extends AdminEvent {
  const AdminStatusFilterChanged(this.statusFilter);
  final String statusFilter; // 'all', 'present', 'late', 'absent'

  @override
  List<Object?> get props => [statusFilter];
}

class AdminQrTypeSelected extends AdminEvent {
  const AdminQrTypeSelected(this.attendanceType);
  final String attendanceType;

  @override
  List<Object?> get props => [attendanceType];
}

class AdminQrDurationSelected extends AdminEvent {
  const AdminQrDurationSelected(this.durationMinutes);
  final int durationMinutes;

  @override
  List<Object?> get props => [durationMinutes];
}

class AdminGenerateQrRequested extends AdminEvent {
  const AdminGenerateQrRequested(this.adminId);
  final String adminId;

  @override
  List<Object?> get props => [adminId];
}

class _AdminQrTimerTicked extends AdminEvent {
  const _AdminQrTimerTicked();
}

// --- States ---
abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {
  const AdminInitial();
}

class AdminLoading extends AdminState {
  const AdminLoading();
}

class AdminLoaded extends AdminState {
  const AdminLoaded({
    required this.selectedDate,
    required this.metrics,
    required this.allEmployees,
    required this.filteredEmployees,
    required this.searchQuery,
    required this.statusFilter,
    required this.isFromRemoteServer,
    required this.selectedQrType,
    required this.selectedQrDurationMinutes,
    this.activeQrPayload,
    this.qrRemaining = Duration.zero,
    this.isQrServerConfirmed = false,
    this.qrWarningMessage,
    this.isGeneratingQr = false,
    this.isLoadingDashboard = false,
  });

  final DateTime selectedDate;
  final AdminDashboardMetrics metrics;
  final List<EmployeeAttendanceSummary> allEmployees;
  final List<EmployeeAttendanceSummary> filteredEmployees;
  final String searchQuery;
  final String statusFilter;
  final bool isFromRemoteServer;

  // QR Generator state
  final String selectedQrType;
  final int selectedQrDurationMinutes;
  final QrPayload? activeQrPayload;
  final Duration qrRemaining;
  final bool isQrServerConfirmed;
  final String? qrWarningMessage;
  final bool isGeneratingQr;
  final bool isLoadingDashboard;

  bool get isQrExpired =>
      activeQrPayload != null && qrRemaining.inSeconds <= 0;

  AdminLoaded copyWith({
    DateTime? selectedDate,
    AdminDashboardMetrics? metrics,
    List<EmployeeAttendanceSummary>? allEmployees,
    List<EmployeeAttendanceSummary>? filteredEmployees,
    String? searchQuery,
    String? statusFilter,
    bool? isFromRemoteServer,
    String? selectedQrType,
    int? selectedQrDurationMinutes,
    QrPayload? activeQrPayload,
    Duration? qrRemaining,
    bool? isQrServerConfirmed,
    String? qrWarningMessage,
    bool clearQrWarning = false,
    bool? isGeneratingQr,
    bool? isLoadingDashboard,
  }) {
    return AdminLoaded(
      selectedDate: selectedDate ?? this.selectedDate,
      metrics: metrics ?? this.metrics,
      allEmployees: allEmployees ?? this.allEmployees,
      filteredEmployees: filteredEmployees ?? this.filteredEmployees,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      isFromRemoteServer: isFromRemoteServer ?? this.isFromRemoteServer,
      selectedQrType: selectedQrType ?? this.selectedQrType,
      selectedQrDurationMinutes:
          selectedQrDurationMinutes ?? this.selectedQrDurationMinutes,
      activeQrPayload: activeQrPayload ?? this.activeQrPayload,
      qrRemaining: qrRemaining ?? this.qrRemaining,
      isQrServerConfirmed: isQrServerConfirmed ?? this.isQrServerConfirmed,
      qrWarningMessage: clearQrWarning
          ? null
          : (qrWarningMessage ?? this.qrWarningMessage),
      isGeneratingQr: isGeneratingQr ?? this.isGeneratingQr,
      isLoadingDashboard: isLoadingDashboard ?? this.isLoadingDashboard,
    );
  }

  @override
  List<Object?> get props => [
        selectedDate,
        metrics,
        allEmployees,
        filteredEmployees,
        searchQuery,
        statusFilter,
        isFromRemoteServer,
        selectedQrType,
        selectedQrDurationMinutes,
        activeQrPayload,
        qrRemaining,
        isQrServerConfirmed,
        qrWarningMessage,
        isGeneratingQr,
        isLoadingDashboard,
      ];
}

class AdminError extends AdminState {
  const AdminError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  AdminBloc({required AdminRepository adminRepository})
      : _repository = adminRepository,
        super(
          AdminLoaded(
            selectedDate: DateTime.now(),
            metrics: const AdminDashboardMetrics(
              totalEmployees: 0,
              presentEmployees: 0,
              absentEmployees: 0,
              lateArrivals: 0,
              checkedOutCount: 0,
              checkedInCount: 0,
            ),
            allEmployees: const [],
            filteredEmployees: const [],
            searchQuery: '',
            statusFilter: 'all',
            isFromRemoteServer: false,
            selectedQrType: AppConstants.typeCheckIn,
            selectedQrDurationMinutes: AppConstants.defaultQrExpiryMinutes,
            isLoadingDashboard: true,
          ),
        ) {
    on<AdminDashboardRequested>(_onDashboardRequested);
    on<AdminSearchQueryChanged>(_onSearchChanged);
    on<AdminStatusFilterChanged>(_onStatusFilterChanged);
    on<AdminQrTypeSelected>(_onQrTypeSelected);
    on<AdminQrDurationSelected>(_onQrDurationSelected);
    on<AdminGenerateQrRequested>(_onGenerateQr);
    on<_AdminQrTimerTicked>(_onQrTimerTicked);

    _syncSubscription = SharedAttendanceSyncStore.instance.onAttendanceChanged
        .listen((record) {
      debugPrint(
        '[ATTENDANCE_DEBUG][Step 9] AdminBloc received event: onAttendanceChanged auto-refresh triggered for employeeId=${record.employeeId}',
      );
      add(const AdminDashboardRequested());
    });
  }

  final AdminRepository _repository;
  Timer? _qrCountdownTimer;
  StreamSubscription<AttendanceModel>? _syncSubscription;
  bool _isLoadingDashboard = false;

  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _selectedQrType = AppConstants.typeCheckIn;
  int _selectedQrDuration = AppConstants.defaultQrExpiryMinutes;

  Future<void> _onDashboardRequested(
    AdminDashboardRequested event,
    Emitter<AdminState> emit,
  ) async {
    if (_isLoadingDashboard) {
      debugPrint(
        '[ATTENDANCE_DEBUG][AdminBloc] Dashboard reload already in progress, skipping duplicate request',
      );
      return;
    }
    _isLoadingDashboard = true;
    _selectedDate = event.date ?? _selectedDate;
    final previous = state;
    debugPrint(
      '[ATTENDANCE_DEBUG][AdminBloc] _onDashboardRequested for date: $_selectedDate',
    );

    try {
      final overview = await _repository.getDashboardOverview(
        date: _selectedDate,
      );
      final filtered = _applyFilters(
        overview.employees,
        query: _searchQuery,
        statusFilter: _statusFilter,
      );

      debugPrint(
        '[ATTENDANCE_DEBUG][AdminBloc] Dashboard loaded: total=${overview.metrics.totalEmployees}, '
        'present=${overview.metrics.presentEmployees}, absent=${overview.metrics.absentEmployees}, '
        'checkedIn=${overview.metrics.checkedInCount}, checkedOut=${overview.metrics.checkedOutCount}',
      );

      if (previous is AdminLoaded) {
        emit(
          previous.copyWith(
            selectedDate: _selectedDate,
            metrics: overview.metrics,
            allEmployees: overview.employees,
            filteredEmployees: filtered,
            isFromRemoteServer: overview.isFromRemoteServer,
            isLoadingDashboard: false,
          ),
        );
      } else {
        emit(
          AdminLoaded(
            selectedDate: _selectedDate,
            metrics: overview.metrics,
            allEmployees: overview.employees,
            filteredEmployees: filtered,
            searchQuery: _searchQuery,
            statusFilter: _statusFilter,
            isFromRemoteServer: overview.isFromRemoteServer,
            selectedQrType: _selectedQrType,
            selectedQrDurationMinutes: _selectedQrDuration,
            isLoadingDashboard: false,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint(
        '[ATTENDANCE_DEBUG][AdminBloc] Error loading dashboard overview: $e\n$stack',
      );
      if (previous is AdminLoaded) {
        emit(
          previous.copyWith(
            isLoadingDashboard: false,
            qrWarningMessage: 'Dashboard load warning: $e',
          ),
        );
      } else {
        emit(AdminError('Failed to load admin overview: $e'));
      }
    } finally {
      _isLoadingDashboard = false;
    }
  }

  void _onSearchChanged(
    AdminSearchQueryChanged event,
    Emitter<AdminState> emit,
  ) {
    _searchQuery = event.query;
    final current = state;
    if (current is AdminLoaded) {
      final filtered = _applyFilters(
        current.allEmployees,
        query: _searchQuery,
        statusFilter: current.statusFilter,
      );
      emit(
        current.copyWith(
          searchQuery: _searchQuery,
          filteredEmployees: filtered,
        ),
      );
    }
  }

  void _onStatusFilterChanged(
    AdminStatusFilterChanged event,
    Emitter<AdminState> emit,
  ) {
    _statusFilter = event.statusFilter;
    final current = state;
    if (current is AdminLoaded) {
      final filtered = _applyFilters(
        current.allEmployees,
        query: current.searchQuery,
        statusFilter: _statusFilter,
      );
      emit(
        current.copyWith(
          statusFilter: _statusFilter,
          filteredEmployees: filtered,
        ),
      );
    }
  }

  void _onQrTypeSelected(
    AdminQrTypeSelected event,
    Emitter<AdminState> emit,
  ) {
    _selectedQrType = event.attendanceType;
    final current = state;
    if (current is AdminLoaded) {
      emit(current.copyWith(selectedQrType: _selectedQrType));
    }
  }

  void _onQrDurationSelected(
    AdminQrDurationSelected event,
    Emitter<AdminState> emit,
  ) {
    _selectedQrDuration = event.durationMinutes;
    final current = state;
    if (current is AdminLoaded) {
      emit(current.copyWith(selectedQrDurationMinutes: _selectedQrDuration));
    }
  }

  Future<void> _onGenerateQr(
    AdminGenerateQrRequested event,
    Emitter<AdminState> emit,
  ) async {
    final current = state;
    if (current is! AdminLoaded) return;

    emit(current.copyWith(isGeneratingQr: true, clearQrWarning: true));
    try {
      final result = await _repository.generateQrSession(
        attendanceType: current.selectedQrType,
        durationMinutes: current.selectedQrDurationMinutes,
        adminId: event.adminId,
      );
      final remaining = result.payload.remainingAt();
      _startQrCountdown();

      emit(
        current.copyWith(
          isGeneratingQr: false,
          activeQrPayload: result.payload,
          qrRemaining: remaining.isNegative ? Duration.zero : remaining,
          isQrServerConfirmed: result.isServerConfirmed,
          qrWarningMessage: result.warningMessage,
        ),
      );
    } catch (e) {
      emit(
        current.copyWith(
          isGeneratingQr: false,
          qrWarningMessage: 'Failed to generate QR session: $e',
        ),
      );
    }
  }

  void _onQrTimerTicked(
    _AdminQrTimerTicked event,
    Emitter<AdminState> emit,
  ) {
    final current = state;
    if (current is! AdminLoaded || current.activeQrPayload == null) return;

    final remaining = current.activeQrPayload!.remainingAt();
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      _qrCountdownTimer?.cancel();
      emit(current.copyWith(qrRemaining: Duration.zero));
    } else {
      emit(current.copyWith(qrRemaining: remaining));
    }
  }

  void _startQrCountdown() {
    _qrCountdownTimer?.cancel();
    _qrCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const _AdminQrTimerTicked()),
    );
  }

  List<EmployeeAttendanceSummary> _applyFilters(
    List<EmployeeAttendanceSummary> list, {
    required String query,
    required String statusFilter,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return list.where((item) {
      final matchesQuery = normalizedQuery.isEmpty ||
          item.employee.name.toLowerCase().contains(normalizedQuery) ||
          item.employee.id.toLowerCase().contains(normalizedQuery) ||
          item.employee.email.toLowerCase().contains(normalizedQuery);

      if (!matchesQuery) return false;

      switch (statusFilter) {
        case 'present':
        case 'checked_in':
          return item.isPresentOrCompleted;
        case 'checked_out':
          return item.record?.isCheckedOut ?? false;
        case 'late':
          return item.isLate;
        case 'absent':
          return !item.isPresentOrCompleted;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Future<void> close() {
    _syncSubscription?.cancel();
    _qrCountdownTimer?.cancel();
    return super.close();
  }
}

/// Manages Admin Shell bottom navigation index without setState.
class AdminNavCubit extends Cubit<int> {
  AdminNavCubit() : super(0);
  void selectTab(int index) => emit(index);
}

