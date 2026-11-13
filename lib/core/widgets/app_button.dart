import 'package:flutter/material.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, emerald, outline, danger, ghost }

/// Custom enterprise button with loading state, icon support, and consistent sizing.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 52,
    this.borderRadius = AppSpacing.radiusMd,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final (Color bg, Color fg, BorderSide? border) = switch (variant) {
      AppButtonVariant.primary => (
          AppColors.primaryNavy,
          AppColors.textOnDark,
          null,
        ),
      AppButtonVariant.secondary => (
          AppColors.secondaryBlue,
          AppColors.textOnDark,
          null,
        ),
      AppButtonVariant.emerald => (
          AppColors.accentEmerald,
          AppColors.textOnDark,
          null,
        ),
      AppButtonVariant.danger => (
          AppColors.error,
          AppColors.textOnDark,
          null,
        ),
      AppButtonVariant.outline => (
          AppColors.surface,
          AppColors.primaryNavy,
          const BorderSide(color: AppColors.borderStrong, width: 1.2),
        ),
      AppButtonVariant.ghost => (
          Colors.transparent,
          AppColors.secondaryBlue,
          null,
        ),
    };

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: fg),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(color: fg),
                ),
              ),
            ],
          );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: Material(
        color: effectiveOnPressed == null
            ? bg.withValues(alpha: 0.55)
            : bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: border ?? BorderSide.none,
        ),
        child: InkWell(
          onTap: effectiveOnPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

