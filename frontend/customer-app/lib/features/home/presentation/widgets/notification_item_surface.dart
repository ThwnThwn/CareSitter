import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';
import 'notification_item_details.dart';

class NotificationItemSurface extends StatelessWidget {
  const NotificationItemSurface({
    super.key,
    required this.notification,
    required this.now,
    required this.iconColor,
    required this.icon,
    required this.onOpen,
    required this.onMarkRead,
  });

  final AppNotification notification;
  final DateTime now;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onOpen;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) => Material(
        color: notification.isRead
            ? AppColors.surface
            : AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.compact,
                AppSpacing.compact, AppSpacing.xs, AppSpacing.compact),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NotificationItemDetails(
                    notification: notification,
                    now: now,
                    iconColor: iconColor,
                    icon: icon,
                  ),
                ),
                if (!notification.isRead)
                  IconButton(
                    tooltip: 'Đánh dấu đã đọc',
                    color: AppColors.primary,
                    onPressed: onMarkRead,
                    icon: const Icon(Icons.done_rounded, size: 20),
                  )
                else
                  const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      );
}
