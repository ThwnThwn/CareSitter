import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeAppointmentTrailingStatus extends StatelessWidget {
  const HomeAppointmentTrailingStatus({super.key, required this.statusBadge});
  final Widget statusBadge;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            statusBadge,
            const SizedBox(height: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textHint,
            ),
          ],
        ),
      ]);
}
