import 'package:flutter/material.dart';
import 'package:newwone/core/theme/app_colors.dart';
import 'package:newwone/core/theme/app_spacing.dart';
import 'package:newwone/core/theme/app_typography.dart';

/// Custom enterprise app bar with optional subtitle and subtle bottom divider.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBackButton = false,
    this.darkStyle = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final bool darkStyle;

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 68 : 58);

  @override
  Widget build(BuildContext context) {
    final bg = darkStyle ? AppColors.primaryNavy : AppColors.surface;
    final fg = darkStyle ? AppColors.textOnDark : AppColors.textPrimary;
    final subColor = darkStyle
        ? Colors.white.withValues(alpha: 0.72)
        : AppColors.textSecondary;

    return AppBar(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      automaticallyImplyLeading: showBackButton,
      leading: leading ??
          (showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null),
      titleSpacing: showBackButton ? 0 : AppSpacing.md,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineMedium.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: subColor),
            ),
          ],
        ],
      ),
      actions: actions,
      bottom: darkStyle
          ? null
          : const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.border),
            ),
    );
  }
}

