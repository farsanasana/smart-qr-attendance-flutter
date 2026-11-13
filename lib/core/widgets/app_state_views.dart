import 'package:flutter/material.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';
import 'package:newwone/core/widgets/app_button.dart';

/// Reusable empty state illustration and message view.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.secondaryBlueSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.secondaryBlue),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable error state card/view with optional retry and secondary actions.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline_rounded,
    this.retryLabel = 'Try Again',
    this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final IconData icon;
  final String retryLabel;
  final VoidCallback? onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          boxShadow: AppSpacing.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            if (onRetry != null || onSecondary != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (onSecondary != null && secondaryLabel != null) ...[
                    Expanded(
                      child: AppButton(
                        label: secondaryLabel!,
                        onPressed: onSecondary,
                        variant: AppButtonVariant.outline,
                        height: 46,
                      ),
                    ),
                    if (onRetry != null) const SizedBox(width: AppSpacing.sm),
                  ],
                  if (onRetry != null)
                    Expanded(
                      child: AppButton(
                        label: retryLabel,
                        onPressed: onRetry,
                        variant: AppButtonVariant.primary,
                        height: 46,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

