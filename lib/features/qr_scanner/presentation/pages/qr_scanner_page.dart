import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:newwone/features/qr_scanner/data/services/location_service.dart';
import 'package:newwone/features/qr_scanner/presentation/bloc/qr_scanner_bloc.dart';

/// Camera-based QR scanner screen with animated scan frame, torch toggle,
/// camera/GPS permission handling, and demo payload testing support.
class QRScannerPage extends StatefulWidget {
  const QRScannerPage({
    super.key,
    required this.user,
    this.onAttendanceRecorded,
    this.onViewDashboardTap,
  });

  final UserEntity user;
  final VoidCallback? onAttendanceRecorded;
  final VoidCallback? onViewDashboardTap;

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  late final AnimationController _laserController;
  bool _isCameraRunning = false;
  bool _isCameraTransitioning = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Keep autoStart: false so BlocConsumer/lifecycle own a single explicit start().
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      autoStart: false,
    );
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);
    context.read<QRScannerBloc>().add(const QrScannerStarted());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<QRScannerBloc>().state is QrScannerScanning) {
        unawaited(_startCameraSafely());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _isDisposed) return;
    final blocState = context.read<QRScannerBloc>().state;
    switch (state) {
      case AppLifecycleState.resumed:
        if (blocState is QrScannerScanning) {
          unawaited(_startCameraSafely());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_stopCameraSafely());
    }
  }

  Future<void> _startCameraSafely() async {
    if (_isDisposed || _isCameraRunning || _isCameraTransitioning) return;
    _isCameraTransitioning = true;
    try {
      await _scannerController.start();
      _isCameraRunning = true;
    } catch (_) {
      _isCameraRunning = false;
      // Handled gracefully by MobileScanner.errorBuilder on camera failures.
    } finally {
      _isCameraTransitioning = false;
    }
  }

  Future<void> _stopCameraSafely() async {
    if (_isDisposed || (!_isCameraRunning && !_isCameraTransitioning)) return;
    _isCameraTransitioning = true;
    try {
      await _scannerController.stop();
    } catch (_) {
      // Ignore if controller is already stopped or not initialized.
    } finally {
      _isCameraRunning = false;
      _isCameraTransitioning = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isCameraRunning = false;
    WidgetsBinding.instance.removeObserver(this);
    _laserController.dispose();
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  Future<void> _showManualPayloadDialog(BuildContext context) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Test QR Payload'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste the JSON payload copied from Admin QR Generator to test validation, GPS capture, SQLite, and Dio sync on an emulator.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: controller,
              hintText: '{"session_id":"SES-...","qr_token":"..."}',
              maxLines: 4,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Validate & Submit'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (raw != null && raw.isNotEmpty && context.mounted) {
      context.read<QRScannerBloc>().add(
            QrCodeDetected(rawPayload: raw, user: widget.user),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationService = context.read<LocationService>();

    return Scaffold(
      backgroundColor: AppColors.primaryNavyDark,
      appBar: CustomAppBar(
        title: 'Scan Attendance QR',
        subtitle: 'Point camera at Admin session QR code',
        darkStyle: true,
        actions: [
          IconButton(
            tooltip: 'Paste QR Payload (Emulator Test)',
            icon: const Icon(Icons.qr_code_2_rounded),
            onPressed: () => _showManualPayloadDialog(context),
          ),
        ],
      ),
      body: BlocConsumer<QRScannerBloc, QRScannerState>(
        listener: (context, state) {
          if (state is QrScannerScanning) {
            unawaited(_startCameraSafely());
            if (!_laserController.isAnimating) {
              _laserController.repeat(reverse: true);
            }
          } else {
            unawaited(_stopCameraSafely());
            if (_laserController.isAnimating) {
              _laserController.stop();
            }
          }
          if (state is QrScannerSuccess) {
            widget.onAttendanceRecorded?.call();
          }
        },
        builder: (context, state) {
          final isScanning = state is QrScannerScanning;
          final scanningState = isScanning ? state : const QrScannerScanning();

          return Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  if (context.read<QRScannerBloc>().state
                      is! QrScannerScanning) {
                    return;
                  }
                  for (final barcode in capture.barcodes) {
                    final value = barcode.rawValue ?? barcode.displayValue;
                    if (value != null && value.trim().isNotEmpty) {
                      context.read<QRScannerBloc>().add(
                            QrCodeDetected(
                              rawPayload: value.trim(),
                              user: widget.user,
                            ),
                          );
                      break;
                    }
                  }
                },
                errorBuilder: (context, error) {
                  final isPermissionError = error.errorCode ==
                      MobileScannerErrorCode.permissionDenied;
                  return Container(
                    color: AppColors.background,
                    child: AppErrorState(
                      icon: isPermissionError
                          ? Icons.no_photography_rounded
                          : Icons.videocam_off_rounded,
                      title: isPermissionError
                          ? 'Camera Permission Denied'
                          : 'Camera Unavailable',
                      message: isPermissionError
                          ? 'Camera access is required to scan attendance QR codes. Enable Camera permission in Settings, or use the top-right Paste QR option on emulators.'
                          : (error.errorDetails?.message ??
                              'Camera hardware is not available on this device. You can test using the Paste QR button in the top bar.'),
                      retryLabel: 'Retry Camera',
                      onRetry: () => unawaited(_startCameraSafely()),
                      secondaryLabel:
                          isPermissionError ? 'Open Settings' : 'Paste QR',
                      onSecondary: isPermissionError
                          ? () => locationService.openAppSettings()
                          : () => _showManualPayloadDialog(context),
                    ),
                  );
                },
              ),
              if (isScanning) ...[
                _ScannerOverlay(laserAnimation: _laserController),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.lg,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withValues(alpha: 0.88),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.gps_fixed_rounded,
                              size: 18,
                              color: AppColors.accentEmerald,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Align the QR code inside the frame. GPS coordinates are captured automatically.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _ScannerControlButton(
                            icon: scanningState.isTorchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            label: scanningState.isTorchOn
                                ? 'Flash On'
                                : 'Flashlight',
                            isActive: scanningState.isTorchOn,
                            onTap: () async {
                              try {
                                await _scannerController.toggleTorch();
                                if (context.mounted) {
                                  context
                                      .read<QRScannerBloc>()
                                      .add(const QrScannerTorchToggled());
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Flashlight is unavailable on this camera.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          _ScannerControlButton(
                            icon: Icons.cameraswitch_rounded,
                            label: 'Flip Camera',
                            isActive: scanningState.isFrontCamera,
                            onTap: () async {
                              try {
                                await _scannerController.switchCamera();
                                if (context.mounted) {
                                  context
                                      .read<QRScannerBloc>()
                                      .add(const QrScannerCameraSwitched());
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Unable to switch camera on this device.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (state is QrScannerProcessing)
                Positioned.fill(
                  child: Container(
                    color: AppColors.background,
                    child: AppProcessingCard(
                      title: 'Verifying Attendance',
                      subtitle: state.stepMessage,
                    ),
                  ),
                ),
              if (state is QrScannerSuccess)
                Positioned.fill(
                  child: _SuccessView(
                    state: state,
                    onDone: () => context
                        .read<QRScannerBloc>()
                        .add(const QrScannerStarted()),
                    onViewDashboard: widget.onViewDashboardTap,
                    onRetrySync: () => context
                        .read<QRScannerBloc>()
                        .add(QrScannerRetrySync(state.record)),
                  ),
                ),
              if (state is QrScannerFailure)
                Positioned.fill(
                  child: Container(
                    color: AppColors.background,
                    child: AppErrorState(
                      icon: _failureIcon(state.failureType),
                      title: state.title,
                      message: state.message,
                      retryLabel: 'Scan Again',
                      onRetry: () => context
                          .read<QRScannerBloc>()
                          .add(const QrScannerStarted()),
                      secondaryLabel: state.canOpenLocationSettings
                          ? 'Location Settings'
                          : (state.canOpenAppSettings ? 'App Settings' : null),
                      onSecondary: state.canOpenLocationSettings
                          ? () => locationService.openLocationSettings()
                          : (state.canOpenAppSettings
                              ? () => locationService.openAppSettings()
                              : null),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _failureIcon(QrFailureType type) {
    return switch (type) {
      QrFailureType.expiredQr => Icons.timer_off_rounded,
      QrFailureType.invalidQr => Icons.qr_code_2_rounded,
      QrFailureType.duplicateCheckIn ||
      QrFailureType.duplicateCheckOut =>
        Icons.block_rounded,
      QrFailureType.noCheckInForCheckOut => Icons.login_rounded,
      QrFailureType.cameraPermissionDenied => Icons.no_photography_rounded,
      QrFailureType.gpsDisabled ||
      QrFailureType.gpsPermissionDenied ||
      QrFailureType.gpsPermissionDeniedForever ||
      QrFailureType.gpsUnavailable =>
        Icons.location_off_rounded,
      QrFailureType.unknown => Icons.error_outline_rounded,
    };
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.laserAnimation});

  final Animation<double> laserAnimation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = (constraints.maxWidth * 0.68).clamp(220.0, 290.0);
        final left = (constraints.maxWidth - boxSize) / 2;
        final top = (constraints.maxHeight - boxSize) / 2 - 28;

        return Stack(
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.54),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    left: left,
                    top: top,
                    child: Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(boxSize, boxSize),
                      painter: _CornerBracketPainter(),
                    ),
                    AnimatedBuilder(
                      animation: laserAnimation,
                      builder: (context, _) {
                        return Positioned(
                          top: 16 + (boxSize - 36) * laserAnimation.value,
                          left: 16,
                          right: 16,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.accentEmerald,
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentEmerald
                                      .withValues(alpha: 0.7),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentEmerald
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 20.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, len),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - r)
        ..quadraticBezierTo(0, size.height, r, size.height)
        ..lineTo(len, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - r, size.height)
        ..quadraticBezierTo(
          size.width,
          size.height,
          size.width,
          size.height - r,
        )
        ..lineTo(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerControlButton extends StatelessWidget {
  const _ScannerControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.accentEmerald
          : Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textOnDark),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  fontSize: 13,
                  color: AppColors.textOnDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.state,
    required this.onDone,
    this.onViewDashboard,
    required this.onRetrySync,
  });

  final QrScannerSuccess state;
  final VoidCallback onDone;
  final VoidCallback? onViewDashboard;
  final VoidCallback onRetrySync;

  @override
  Widget build(BuildContext context) {
    final isCheckIn = state.attendanceType == AppConstants.typeCheckIn;
    final timestamp =
        isCheckIn ? state.record.checkInTime : state.record.checkOutTime;
    final lat = isCheckIn
        ? state.record.latitude
        : (state.record.checkoutLatitude ?? state.record.latitude);
    final lng = isCheckIn
        ? state.record.longitude
        : (state.record.checkoutLongitude ?? state.record.longitude);

    return Container(
      color: AppColors.background,
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: AppColors.accentEmeraldSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 46,
                color: AppColors.accentEmeraldDark,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isCheckIn ? 'Check-In Recorded!' : 'Check-Out Recorded!',
              style: AppTypography.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            SyncStatusBadge(
              syncStatus: state.record.syncStatus,
              onRetryTap: state.isServerConfirmed ? null : onRetrySync,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.border),
                boxShadow: AppSpacing.cardShadow,
              ),
              child: Column(
                children: [
                  _SummaryItem(
                    'Employee',
                    '${state.record.employeeName} (${state.record.employeeId})',
                  ),
                  _SummaryItem('Session ID', state.record.sessionId),
                  _SummaryItem(
                    'Recorded Time',
                    timestamp != null
                        ? '${AppDateUtils.formatShortDate(timestamp)} • ${AppDateUtils.formatTimeWithSeconds(timestamp)}'
                        : '--',
                  ),
                  _SummaryItem(
                    'GPS Coordinates',
                    lat != null && lng != null
                        ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                        : 'Not available',
                  ),
                  _SummaryItem(
                    'Storage',
                    state.isServerConfirmed
                        ? 'SQLite + Server Confirmed'
                        : 'Saved in Local SQLite (Sync Pending)',
                  ),
                ],
              ),
            ),
            if (!state.isServerConfirmed && state.warningMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.warningDark,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        state.warningMessage!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.warningDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (!state.isServerConfirmed) ...[
              AppButton(
                label: 'Retry Server Sync',
                icon: Icons.cloud_upload_rounded,
                variant: AppButtonVariant.outline,
                isLoading: state.isSyncing,
                onPressed: onRetrySync,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (onViewDashboard != null) ...[
              AppButton(
                label: 'View in Dashboard',
                icon: Icons.dashboard_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  onDone();
                  onViewDashboard!();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Ready to Scan Another QR',
                icon: Icons.qr_code_scanner_rounded,
                variant: AppButtonVariant.outline,
                onPressed: onDone,
              ),
            ] else
              AppButton(
                label: 'Done & Ready to Scan',
                variant: AppButtonVariant.primary,
                onPressed: onDone,
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.labelLarge.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

