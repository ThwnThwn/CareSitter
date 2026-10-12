import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class NotificationsEmptyState extends StatelessWidget {
  const NotificationsEmptyState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 64, color: AppColors.textHint),
            SizedBox(height: AppSpacing.md),
            Text(
              'Không có thông báo nào',
              style: TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
}
