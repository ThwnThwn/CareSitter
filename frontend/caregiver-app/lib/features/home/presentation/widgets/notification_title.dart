import 'package:caregiver_app/features/home/data/models/notification_model.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class NotificationTitle extends StatelessWidget {
  const NotificationTitle(
      {super.key, required this.notif, required this.isRead});
  final AppNotificationModel notif;
  final bool isRead;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              notif.title,
              style: TextStyle(
                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                fontSize: AppFontSizes.s14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      );
}
