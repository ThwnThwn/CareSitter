import 'package:caresitter_customer/features/home/presentation/widgets/notification_item_details.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class NotificationItemSurface extends StatelessWidget {
  const NotificationItemSurface(
      {super.key,
      required this.notification,
      required this.iconColor,
      required this.icon,
      required this.route});
  final AppNotification notification;
  final Color iconColor;
  final IconData icon;
  final String? route;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
            ? Duration.zero
            : const Duration(milliseconds: 180),
        color: notification.isRead
            ? Colors.transparent
            : AppColors.primary.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.inset),
        child: NotificationItemDetails(
            iconColor: iconColor,
            icon: icon,
            notification: notification,
            route: route),
      );
}
