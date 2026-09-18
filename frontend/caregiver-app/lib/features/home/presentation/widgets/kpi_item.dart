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
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        valueWidget ??
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value ?? '',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: unit != null ? 24 : 18,
                    fontWeight: FontWeight.w700,
                    color: unit != null
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit!,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
        const SizedBox(height: 4),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              badge!,
              style: GoogleFonts.beVietnamPro(
                fontSize: 10,
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
