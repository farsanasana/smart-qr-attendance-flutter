import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/utils/app_date_utils.dart';
import 'package:newwone/core/widgets/core_widgets.dart';
import 'package:newwone/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:newwone/features/auth/domain/entities/user_entity.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Admin dynamic time-limited QR attendance session generator screen.
class AdminQrGeneratorPage extends StatelessWidget {
  const AdminQrGeneratorPage({
    super.key,
    required this.admin,
  });

  final UserEntity admin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(
        title: 'QR Session Generator',
        subtitle: 'Time-limited check-in & check-out QR tokens',
      ),
      body: BlocBuilder<AdminBloc, AdminState>(
        builder: (context, state) {
          if (state is AdminInitial || state is AdminLoading) {
            return const AppLoadingIndicator(
              message: 'Preparing QR session controls...',
            );
          }

          if (state is AdminError) {
            return AppErrorState(
              title: 'QR Generator Error',
              message: state.message,
              onRetry: () => context
                  .read<AdminBloc>()
                  .add(const AdminDashboardRequested()),
            );
          }

          if (state is! AdminLoaded) {
            return const AppLoadingIndicator(
              message: 'Preparing QR session controls...',
            );
          }

          return SingleChildScrollView(
            padding: AppSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildConfigCard(context, state),
                const SizedBox(height: AppSpacing.md),
                if (state.activeQrPayload != null)
                  _buildGeneratedQrCard(context, state)
                else
                  const AppEmptyState(
                    icon: Icons.qr_code_2_rounded,
                    title: 'No Active QR Session',
                    message:
                        'Select an attendance type and expiry duration above, then tap Generate QR Session.',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigCard(BuildContext context, AdminLoaded state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session Configuration', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Attendance Type',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _TypeOptionButton(
                  label: 'Check-In',
                  icon: Icons.login_rounded,
                  isSelected:
                      state.selectedQrType == AppConstants.typeCheckIn,
                  activeColor: AppColors.accentEmerald,
                  onTap: () => context.read<AdminBloc>().add(
                        const AdminQrTypeSelected(AppConstants.typeCheckIn),
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TypeOptionButton(
                  label: 'Check-Out',
                  icon: Icons.logout_rounded,
                  isSelected:
                      state.selectedQrType == AppConstants.typeCheckOut,
                  activeColor: AppColors.secondaryBlue,
                  onTap: () => context.read<AdminBloc>().add(
                        const AdminQrTypeSelected(AppConstants.typeCheckOut),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Expiry Duration',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: AppConstants.qrExpiryOptionsMinutes.map((mins) {
              final selected = state.selectedQrDurationMinutes == mins;
              return ChoiceChip(
                label: Text('$mins min'),
                selected: selected,
                selectedColor: AppColors.primaryNavy,
                backgroundColor: AppColors.surfaceSubtle,
                labelStyle: AppTypography.labelSmall.copyWith(
                  color:
                      selected ? AppColors.textOnDark : AppColors.textSecondary,
                ),
                side: BorderSide.none,
                onSelected: (_) => context
                    .read<AdminBloc>()
                    .add(AdminQrDurationSelected(mins)),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: state.activeQrPayload == null
                ? 'Generate QR Session'
                : 'Regenerate New QR',
            icon: Icons.qr_code_rounded,
            isLoading: state.isGeneratingQr,
            onPressed: () => context
                .read<AdminBloc>()
                .add(AdminGenerateQrRequested(admin.id)),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedQrCard(BuildContext context, AdminLoaded state) {
    final payload = state.activeQrPayload!;
    final isExpired = state.isQrExpired;
    final rawJson = payload.toRawPayload();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: isExpired
              ? AppColors.error.withValues(alpha: 0.4)
              : AppColors.border,
        ),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(
                label: payload.isCheckIn ? 'CHECK-IN QR' : 'CHECK-OUT QR',
                color: payload.isCheckIn
                    ? AppColors.accentEmeraldDark
                    : AppColors.secondaryBlue,
                backgroundColor: payload.isCheckIn
                    ? AppColors.accentEmeraldSoft
                    : AppColors.secondaryBlueSoft,
                icon: payload.isCheckIn
                    ? Icons.login_rounded
                    : Icons.logout_rounded,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isExpired ? AppColors.errorSoft : AppColors.infoSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
                      size: 14,
                      color:
                          isExpired ? AppColors.error : AppColors.secondaryBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isExpired
                          ? 'EXPIRED'
                          : 'Valid ${AppDateUtils.formatCountdown(state.qrRemaining)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: isExpired
                            ? AppColors.error
                            : AppColors.secondaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Opacity(
                  opacity: isExpired ? 0.2 : 1.0,
                  child: QrImageView(
                    data: rawJson,
                    version: QrVersions.auto,
                    size: 210,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.primaryNavy,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
              ),
              if (isExpired)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(
                    'QR EXPIRED — REGENERATE',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SyncStatusBadge(
            syncStatus: state.isQrServerConfirmed
                ? AppConstants.syncServerConfirmed
                : AppConstants.syncLocalPending,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              children: [
                _MetaRow('Session ID', payload.sessionId),
                _MetaRow('QR Token', payload.qrToken),
                _MetaRow(
                  'Expires At',
                  AppDateUtils.formatTimeWithSeconds(payload.expiresAt.toLocal()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Copy QR JSON Payload (Test)',
            icon: Icons.copy_rounded,
            variant: AppButtonVariant.outline,
            height: 46,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: rawJson));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'QR JSON copied! You can paste it in Employee Scanner -> Paste QR.',
                    ),
                  ),
                );
              }
            },
          ),
          if (state.qrWarningMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.qrWarningMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.warningDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeOptionButton extends StatelessWidget {
  const _TypeOptionButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? activeColor.withValues(alpha: 0.12)
          : AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  fontSize: 13.5,
                  color: isSelected ? activeColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

