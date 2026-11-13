import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';

/// Root Material 3 theme configured for the Smart Attendance design system.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryNavy,
      onPrimary: AppColors.textOnDark,
      primaryContainer: AppColors.secondaryBlueSoft,
      onPrimaryContainer: AppColors.primaryNavy,
      secondary: AppColors.secondaryBlue,
      onSecondary: AppColors.textOnDark,
      secondaryContainer: AppColors.secondaryBlueLight,
      onSecondaryContainer: AppColors.primaryNavy,
      tertiary: AppColors.accentEmerald,
      onTertiary: AppColors.textOnDark,
      tertiaryContainer: AppColors.accentEmeraldSoft,
      onTertiaryContainer: AppColors.accentEmeraldDark,
      error: AppColors.error,
      onError: AppColors.textOnDark,
      errorContainer: AppColors.errorSoft,
      onErrorContainer: AppColors.errorDark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceSubtle,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderStrong,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryNavy,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textOnDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: AppTypography.displayLarge,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        titleMedium: AppTypography.titleMedium,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
        labelSmall: AppTypography.labelSmall,
      ),
    );
  }
}

