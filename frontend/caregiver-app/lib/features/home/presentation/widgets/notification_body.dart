import 'package:caregiver_app/features/home/data/models/notification_model.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class NotificationBody extends StatelessWidget {
  const NotificationBody({super.key, required this.notif});
  final AppNotificationModel notif;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xs),
          Text(
            notif.body,
            style: const TextStyle(
              fontSize: AppFontSizes.s12Point5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.tight),
          Text(
            notif.time,
            style: const TextStyle(
              fontSize: AppFontSizes.s11,
              color: AppColors.textHint,
            ),
          ),
        ],
      );
}
