import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

/// Row item trong Settings — thiết kế chuẩn theo Stitch:
/// icon nằm trong box bo tròn có màu sắc riêng, tiêu đề, mô tả và trailing tuỳ biến.
class SettingsSettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconBackgroundColor;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback onTap;

  const SettingsSettingsItem({
    super.key,
    required this.icon,
    this.iconBackgroundColor = AppColors.primaryContainer,
    this.iconColor = AppColors.primary,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.showDivider = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          splashColor: iconColor.withValues(alpha: 0.08),
          highlightColor: iconColor.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor ?? AppColors.textPrimary,
                          fontSize: AppFontSizes.s14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFontSizes.s12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Trailing
                trailing ??
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textHint,
                      size: 20,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 68,
            endIndent: 0,
            color: Color(0xFFF1F5F4),
          ),
      ],
    );
  }
}
