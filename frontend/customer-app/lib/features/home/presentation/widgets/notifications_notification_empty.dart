import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class NotificationsNotificationEmpty extends StatelessWidget {
  const NotificationsNotificationEmpty({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_outlined,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Chưa có thông báo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Các thông báo về lịch hẹn sẽ hiển thị ở đây',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
