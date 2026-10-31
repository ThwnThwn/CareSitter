import 'package:caresitter_customer/features/home/presentation/widgets/notification_item_surface.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/notifications_presentation_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class NotificationsNotificationItem extends ConsumerWidget {
  const NotificationsNotificationItem({super.key, required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = notification.data['status']?.toString();
    final icon = notificationsIconFor(notification.type, status: status);
    final iconColor =
        notificationsIconColorFor(notification.type, status: status);
    final route = notification.data['deepLink']?.toString();
    return InkWell(
      onTap: () async {
        await ref
            .read(notificationsProvider.notifier)
            .markRead(notification.id)
            .catchError((_) {});
        if (!context.mounted) return;
        await ref.read(notificationDeepLinkServiceProvider).handle({
          'type': notification.type,
          ...notification.data,
        });
      },
      child: NotificationItemSurface(
          notification: notification,
          iconColor: iconColor,
          icon: icon,
          route: route),
    );
  }
}
