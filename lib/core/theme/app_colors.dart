import 'package:flutter/material.dart';

/// Enterprise SaaS color system for Smart Attendance.
class AppColors {
  AppColors._();

  // Brand Palette
  static const Color primaryNavy = Color(0xFF0F2342);
  static const Color primaryNavyLight = Color(0xFF1A3661);
  static const Color primaryNavyDark = Color(0xFF09172E);

  static const Color secondaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlueLight = Color(0xFFDBEAFE);
  static const Color secondaryBlueSoft = Color(0xFFEFF6FF);

  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentEmeraldDark = Color(0xFF059669);
  static const Color accentEmeraldSoft = Color(0xFFD1FAE5);

  // Neutral Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color errorSoft = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFEFF6FF);

  // Gradients
  static const LinearGradient navyHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryNavyDark, primaryNavy, primaryNavyLight],
  );

  static const LinearGradient blueActionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryBlue, Color(0xFF1D4ED8)],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentEmerald, accentEmeraldDark],
  );
}

