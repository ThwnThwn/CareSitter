import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeAppointmentInlineStatus extends StatelessWidget {
  const HomeAppointmentInlineStatus({super.key, required this.statusBadge});
  final Widget statusBadge;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 7),
            Row(
              children: [
                Flexible(child: statusBadge),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ]);
}
