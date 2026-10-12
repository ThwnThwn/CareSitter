import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Teal gradient app header card
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double height;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.s28),
          bottomRight: Radius.circular(AppRadius.s28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.section, AppSpacing.md,
          AppSpacing.section, AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (trailing != null)
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                        fontSize: AppFontSizes.s22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                ),
                trailing!,
              ],
            )
          else
            Text(title,
                style: const TextStyle(
                  fontSize: AppFontSizes.s22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: AppFontSizes.s13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
