import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';
import 'notification_item_surface.dart';
import 'notifications_presentation_helpers.dart';

class NotificationsNotificationItem extends StatelessWidget {
  const NotificationsNotificationItem({
    super.key,
    required this.notification,
    required this.now,
    required this.onOpen,
    required this.onMarkRead,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onOpen;
  final Future<void> Function() onMarkRead;

  @override
  Widget build(BuildContext context) {
    final status = notification.data['status']?.toString();
    final tile = NotificationItemSurface(
      notification: notification,
      now: now,
      icon: notificationsIconFor(notification.type, status: status),
      iconColor: notificationsIconColorFor(notification.type, status: status),
      onOpen: onOpen,
      onMarkRead: onMarkRead,
    );
    return Dismissible(
      key: ValueKey(notification.key),
      direction: notification.isRead
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await onMarkRead();
        return false;
      },
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(
          Icons.done_rounded,
          color: AppColors.surface,
          semanticLabel: 'Đánh dấu đã đọc',
        ),
      ),
      child: tile,
    );
  }
}
