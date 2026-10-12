import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';

/// KPI card item
class KpiItem extends StatelessWidget {
  final String label;
  final String? value;
  final String? unit;
  final String? badge;
  final Color? badgeColor;
  final Widget? trailing;
  final Widget? valueWidget;

  const KpiItem({
    super.key,
    required this.label,
    this.value,
    this.unit,
    this.badge,
    this.badgeColor,
    this.trailing,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: AppFontSizes.s12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        valueWidget ??
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value ?? '',
                  style: GoogleFonts.beVietnamPro(
                    fontSize:
                        unit != null ? AppFontSizes.s24 : AppFontSizes.s18,
                    fontWeight: FontWeight.w700,
                    color: unit != null
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: AppSpacing.micro),
                  Text(
                    unit!,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: AppFontSizes.s11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
        const SizedBox(height: AppSpacing.xs),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.tight, vertical: AppSpacing.micro),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              badge!,
              style: GoogleFonts.beVietnamPro(
                fontSize: AppFontSizes.s10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
