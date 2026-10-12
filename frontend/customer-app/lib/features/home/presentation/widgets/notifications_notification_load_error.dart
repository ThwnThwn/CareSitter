import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class NotificationsNotificationLoadError extends StatelessWidget {
  const NotificationsNotificationLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.textSecondary,
                size: 36,
              ),
              const SizedBox(height: AppSpacing.compact),
              const Text('Không thể tải thông báo'),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
}
