import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/database/app_database.dart';
import 'package:newwone/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:newwone/features/attendance/domain/entities/attendance_entity.dart';
import 'package:newwone/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:newwone/features/qr_scanner/data/services/location_service.dart';
import 'package:newwone/features/qr_scanner/domain/entities/qr_payload.dart';

enum QrFailureType {
  invalidQr,
  expiredQr,
  duplicateCheckIn,
  noCheckInForCheckOut,
  duplicateCheckOut,
  cameraPermissionDenied,
  gpsPermissionDenied,
  gpsPermissionDeniedForever,
  gpsDisabled,
  gpsUnavailable,
  unknown,
}

// --- Events ---
abstract class QRScannerEvent extends Equatable {
  const QRScannerEvent();

  @override
  List<Object?> get props => [];
}

class QrScannerStarted extends QRScannerEvent {
  const QrScannerStarted();
}

class QrCodeDetected extends QRScannerEvent {
  const QrCodeDetected({
    required this.rawPayload,
    required this.user,
  });

  final String rawPayload;
  final UserEntity user;

  @override
  List<Object?> get props => [rawPayload, user];
}

class QrScannerTorchToggled extends QRScannerEvent {
  const QrScannerTorchToggled();
}

class QrScannerCameraSwitched extends QRScannerEvent {
  const QrScannerCameraSwitched();
}

class QrScannerPermissionDenied extends QRScannerEvent {
  const QrScannerPermissionDenied(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class QrScannerRetrySync extends QRScannerEvent {
  const QrScannerRetrySync(this.record);
  final AttendanceEntity record;

  @override
  List<Object?> get props => [record];
}

// --- States ---
abstract class QRScannerState extends Equatable {
  const QRScannerState();

  @override
  List<Object?> get props => [];
}

class QrScannerScanning extends QRScannerState {
  const QrScannerScanning({
    this.isTorchOn = false,
    this.isFrontCamera = false,
  });

  final bool isTorchOn;
  final bool isFrontCamera;

  QrScannerScanning copyWith({
    bool? isTorchOn,
    bool? isFrontCamera,
  }) {
    return QrScannerScanning(
      isTorchOn: isTorchOn ?? this.isTorchOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
    );
  }

  @override
  List<Object?> get props => [isTorchOn, isFrontCamera];
}

class QrScannerProcessing extends QRScannerState {
  const QrScannerProcessing(this.stepMessage);
  final String stepMessage;

  @override
  List<Object?> get props => [stepMessage];
}

class QrScannerSuccess extends QRScannerState {
  const QrScannerSuccess({
    required this.record,
    required this.attendanceType,
    required this.isServerConfirmed,
    this.warningMessage,
    this.isSyncing = false,
  });

  final AttendanceEntity record;
  final String attendanceType;
  final bool isServerConfirmed;
  final String? warningMessage;
  final bool isSyncing;

  @override
  List<Object?> get props => [
        record,
        attendanceType,
        isServerConfirmed,
        warningMessage,
        isSyncing,
      ];
}

class QrScannerFailure extends QRScannerState {
  const QrScannerFailure({
    required this.title,
    required this.message,
    required this.failureType,
  });

  final String title;
  final String message;
  final QrFailureType failureType;

  bool get canOpenAppSettings =>
      failureType == QrFailureType.cameraPermissionDenied ||
      failureType == QrFailureType.gpsPermissionDeniedForever;

  bool get canOpenLocationSettings =>
      failureType == QrFailureType.gpsDisabled;

  @override
  List<Object?> get props => [title, message, failureType];
}

/// Optional callback used to cross-check locally generated admin QR sessions.
typedef QrTokenVerifier = Future<bool> Function(
  String sessionId,
  String qrToken,
);

/// Detailed verification result for local SQLite QR session checks.
class _QrSessionVerificationResult {
  const _QrSessionVerificationResult({
    required this.isValid,
    this.errorTitle,
    this.errorMessage,
    this.failureType = QrFailureType.invalidQr,
  });

  final bool isValid;
  final String? errorTitle;
  final String? errorMessage;
  final QrFailureType failureType;
}

// --- BLoC ---
class QRScannerBloc extends Bloc<QRScannerEvent, QRScannerState> {
  QRScannerBloc({
    required AttendanceRepository attendanceRepository,
    required LocationService locationService,
    QrTokenVerifier? localTokenVerifier,
    this.allowCrossDeviceDemoQr = true,
  })  : _attendanceRepository = attendanceRepository,
        _locationService = locationService,
        _localTokenVerifier = localTokenVerifier,
        super(const QrScannerScanning()) {
    on<QrScannerStarted>(_onStarted);
    on<QrCodeDetected>(_onCodeDetected);
    on<QrScannerTorchToggled>(_onTorchToggled);
    on<QrScannerCameraSwitched>(_onCameraSwitched);
    on<QrScannerPermissionDenied>(_onPermissionDenied);
    on<QrScannerRetrySync>(_onRetrySync);
  }

  final AttendanceRepository _attendanceRepository;
  final LocationService _locationService;
  final QrTokenVerifier? _localTokenVerifier;
  final bool allowCrossDeviceDemoQr;

  Future<_QrSessionVerificationResult> _verifySession(
    QrPayload payload,
    String employeeId,
  ) async {
    if (_localTokenVerifier != null) {
      try {
        final ok = await _localTokenVerifier(payload.sessionId, payload.qrToken);
        return ok
            ? const _QrSessionVerificationResult(isValid: true)
            : const _QrSessionVerificationResult(
                isValid: false,
                errorTitle: 'Invalid Session Token',
                errorMessage:
                    'The scanned QR token does not match the active session record.',
              );
      } catch (_) {
        return const _QrSessionVerificationResult(
          isValid: false,
          errorTitle: 'QR Verification Error',
          errorMessage: 'Unable to verify the scanned QR token.',
        );
      }
    }

    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        AppDatabase.qrSessionsTable,
        where: 'session_id = ?',
        whereArgs: [payload.sessionId],
        limit: 1,
      );
      if (rows.isEmpty) {
        if (!allowCrossDeviceDemoQr) {
          return const _QrSessionVerificationResult(
            isValid: false,
            errorTitle: 'Unrecognized QR Session',
            errorMessage:
                'This QR session was not issued on this device and strict local verification is enabled.',
          );
        }
        // Cross-device demo QR codes are allowed if structurally valid and
        // unexpired; production backends must validate token server-side.
        return const _QrSessionVerificationResult(isValid: true);
      }

      final row = rows.first;
      if (row['qr_token']?.toString() != payload.qrToken) {
        return const _QrSessionVerificationResult(
          isValid: false,
          errorTitle: 'Invalid Session Token',
          errorMessage:
              'The scanned QR token does not match the issued session record.',
        );
      }
      if (row['attendance_type']?.toString() != payload.attendanceType) {
        return const _QrSessionVerificationResult(
          isValid: false,
          errorTitle: 'Invalid QR Type',
          errorMessage:
              'The scanned QR attendance type does not match the issued session.',
        );
      }
      final storedExpiry = DateTime.tryParse(
        row['expires_at']?.toString() ?? '',
      );
      if (storedExpiry == null ||
          storedExpiry
                  .toUtc()
                  .difference(payload.expiresAt.toUtc())
                  .inSeconds
                  .abs() >
              2) {
        return const _QrSessionVerificationResult(
          isValid: false,
          errorTitle: 'Tampered QR Session',
          errorMessage:
              'QR expiration timestamp does not match the issued session.',
        );
      }
      final consumedBy = row['consumed_by']?.toString();
      if (consumedBy != null && consumedBy == employeeId) {
        return _QrSessionVerificationResult(
          isValid: false,
          errorTitle: 'QR Code Already Used',
          errorMessage:
              'This QR session has already been used by your account.',
          failureType: payload.isCheckIn
              ? QrFailureType.duplicateCheckIn
              : QrFailureType.duplicateCheckOut,
        );
      }
      return const _QrSessionVerificationResult(isValid: true);
    } catch (_) {
      // Fail closed if local verification storage errors out.
      return const _QrSessionVerificationResult(
        isValid: false,
        errorTitle: 'Verification Failed',
        errorMessage:
            'Could not verify QR session against the local database.',
      );
    }
  }

  void _onStarted(QrScannerStarted event, Emitter<QRScannerState> emit) {
    emit(const QrScannerScanning());
  }

  void _onTorchToggled(
    QrScannerTorchToggled event,
    Emitter<QRScannerState> emit,
  ) {
    final current = state;
    if (current is QrScannerScanning) {
      emit(current.copyWith(isTorchOn: !current.isTorchOn));
    }
  }

  void _onCameraSwitched(
    QrScannerCameraSwitched event,
    Emitter<QRScannerState> emit,
  ) {
    final current = state;
    if (current is QrScannerScanning) {
      emit(current.copyWith(isFrontCamera: !current.isFrontCamera));
    }
  }

  void _onPermissionDenied(
    QrScannerPermissionDenied event,
    Emitter<QRScannerState> emit,
  ) {
    emit(
      QrScannerFailure(
        title: 'Camera Permission Required',
        message: event.message,
        failureType: QrFailureType.cameraPermissionDenied,
      ),
    );
  }

  Future<void> _onCodeDetected(
    QrCodeDetected event,
    Emitter<QRScannerState> emit,
  ) async {
    // Ignore duplicate camera frames while already processing or showing result.
    if (state is! QrScannerScanning) return;

    debugPrint(
      '[ATTENDANCE_DEBUG][Step 1] QR detected: employeeId=${event.user.id}, '
      'name=${event.user.name}, rawPayloadLength=${event.rawPayload.length}',
    );

    emit(const QrScannerProcessing('Validating attendance QR token...'));

    final payload = QrPayload.tryParse(event.rawPayload);
    if (payload == null) {
      debugPrint('[ATTENDANCE_DEBUG][QRScannerBloc] QR payload parsing failed.');
      emit(
        const QrScannerFailure(
          title: 'Invalid QR Code',
          message:
              'This QR code does not match the Smart Attendance session format.',
          failureType: QrFailureType.invalidQr,
        ),
      );
      return;
    }

    debugPrint(
      '[ATTENDANCE_DEBUG][Step 2] QR signature validated: sessionId=${payload.sessionId}, '
      'qrToken=${payload.qrToken}, signature=${payload.signature}, '
      'hasValidIntegrityTag=${payload.hasValidIntegrityTag}',
    );

    final verification = await _verifySession(payload, event.user.id);
    if (!verification.isValid) {
      emit(
        QrScannerFailure(
          title: verification.errorTitle ?? 'Invalid Session Token',
          message: verification.errorMessage ??
              'The scanned QR token does not match the active session record.',
          failureType: verification.failureType,
        ),
      );
      return;
    }

    final isExpired = payload.isExpiredAt();
    debugPrint(
      '[ATTENDANCE_DEBUG][Step 3] QR expiry validated: expiresAt=${payload.expiresAt}, '
      'isExpired=$isExpired',
    );

    if (isExpired) {
      emit(
        const QrScannerFailure(
          title: 'QR Code Expired',
          message:
              'This attendance QR session has expired. Ask your administrator to generate a new QR code.',
          failureType: QrFailureType.expiredQr,
        ),
      );
      return;
    }

    // Check duplicate check-in / valid check-in before checkout BEFORE GPS call
    // so users get immediate rule feedback.
    final todayRecord = await _attendanceRepository.getTodayAttendance(
      event.user.id,
    );
    if (todayRecord != null &&
        (todayRecord.sessionId == payload.sessionId ||
            todayRecord.checkoutSessionId == payload.sessionId)) {
      emit(
        QrScannerFailure(
          title: 'QR Session Already Used',
          message:
              'This QR session ID has already been recorded for your attendance today.',
          failureType: payload.isCheckIn
              ? QrFailureType.duplicateCheckIn
              : QrFailureType.duplicateCheckOut,
        ),
      );
      return;
    }
    if (payload.isCheckIn && todayRecord != null && todayRecord.isCheckedIn) {
      emit(
        const QrScannerFailure(
          title: 'Already Checked In',
          message:
              'Duplicate check-in prevented. You have already recorded check-in for today.',
          failureType: QrFailureType.duplicateCheckIn,
        ),
      );
      return;
    }
    if (payload.isCheckOut) {
      if (todayRecord == null || !todayRecord.isCheckedIn) {
        emit(
          const QrScannerFailure(
            title: 'Check-In Required First',
            message:
                'You cannot check out without an active check-in today. Please scan a Check-In QR code first.',
            failureType: QrFailureType.noCheckInForCheckOut,
          ),
        );
        return;
      }
      if (todayRecord.isCheckedOut) {
        emit(
          const QrScannerFailure(
            title: 'Already Checked Out',
            message:
                'Duplicate check-out prevented. Your attendance for today is already completed.',
            failureType: QrFailureType.duplicateCheckOut,
          ),
        );
        return;
      }
    }

    emit(const QrScannerProcessing('Capturing GPS location...'));
    late CapturedCoordinates coords;
    try {
      coords = await _locationService.captureCurrentLocation();
      debugPrint(
        '[ATTENDANCE_DEBUG][Step 4] GPS captured: lat=${coords.latitude}, '
        'lng=${coords.longitude}',
      );
    } on LocationFailure catch (e) {
      final type = switch (e.type) {
        LocationFailureType.serviceDisabled => QrFailureType.gpsDisabled,
        LocationFailureType.permissionDenied =>
          QrFailureType.gpsPermissionDenied,
        LocationFailureType.permissionDeniedForever =>
          QrFailureType.gpsPermissionDeniedForever,
        LocationFailureType.unavailable => QrFailureType.gpsUnavailable,
      };
      emit(
        QrScannerFailure(
          title: 'GPS Verification Failed',
          message: e.message,
          failureType: type,
        ),
      );
      return;
    }

    emit(
      QrScannerProcessing(
        payload.isCheckIn
            ? 'Saving Check-In to SQLite & syncing...'
            : 'Saving Check-Out to SQLite & syncing...',
      ),
    );

    try {
      final result = payload.isCheckIn
          ? await _attendanceRepository.submitCheckIn(
              employeeId: event.user.id,
              employeeName: event.user.name,
              sessionId: payload.sessionId,
              qrToken: payload.qrToken,
              latitude: coords.latitude,
              longitude: coords.longitude,
            )
          : await _attendanceRepository.submitCheckOut(
              employeeId: event.user.id,
              employeeName: event.user.name,
              sessionId: payload.sessionId,
              qrToken: payload.qrToken,
              latitude: coords.latitude,
              longitude: coords.longitude,
            );

      debugPrint(
        '[ATTENDANCE_DEBUG][QRScannerBloc] Attendance SUCCESS: recordId=${result.record.id}, '
        'empId=${result.record.employeeId}, status=${result.record.status}, '
        'checkInTime=${result.record.checkInTime}, isServerConfirmed=${result.isServerConfirmed}',
      );

      emit(
        QrScannerSuccess(
          record: result.record,
          attendanceType: payload.attendanceType,
          isServerConfirmed: result.isServerConfirmed,
          warningMessage: result.warningMessage,
        ),
      );
    } on AttendanceRuleException catch (e) {
      emit(
        QrScannerFailure(
          title: 'Attendance Rule Violation',
          message: e.message,
          failureType: payload.isCheckIn
              ? QrFailureType.duplicateCheckIn
              : QrFailureType.noCheckInForCheckOut,
        ),
      );
    } catch (e) {
      emit(
        QrScannerFailure(
          title: 'Attendance Failed',
          message: 'Could not complete attendance: $e',
          failureType: QrFailureType.unknown,
        ),
      );
    }
  }

  Future<void> _onRetrySync(
    QrScannerRetrySync event,
    Emitter<QRScannerState> emit,
  ) async {
    final current = state;
    if (current is! QrScannerSuccess) return;

    emit(
      QrScannerSuccess(
        record: current.record,
        attendanceType: current.attendanceType,
        isServerConfirmed: current.isServerConfirmed,
        warningMessage: current.warningMessage,
        isSyncing: true,
      ),
    );

    final result = await _attendanceRepository.retrySyncRecord(event.record);
    emit(
      QrScannerSuccess(
        record: result.record,
        attendanceType: current.attendanceType,
        isServerConfirmed: result.isServerConfirmed,
        warningMessage: result.warningMessage,
        isSyncing: false,
      ),
    );
  }
}

