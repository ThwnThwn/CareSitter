import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeAppointmentStatusBadge extends StatelessWidget {
  const HomeAppointmentStatusBadge(
      {super.key,
      required this.statusBg,
      required this.statusLabel,
      required this.statusColor});
  final Color statusBg;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: statusBg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Text(
          statusLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: statusColor,
            fontSize: AppFontSizes.s10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
