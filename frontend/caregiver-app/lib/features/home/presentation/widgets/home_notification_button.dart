import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import '../controllers/notifications_controller.dart';

class HomeNotificationButton extends ConsumerWidget {
  const HomeNotificationButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider.select((notifications) =>
        notifications.any((notification) => !notification.isRead)));
    return Stack(children: [
      IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AppColors.textPrimary),
          onPressed: () => context.push('/notifications')),
      if (unread)
        Positioned(
            top: 10,
            right: 10,
            child: Container(
              key: const ValueKey('home-unread-notifications'),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.cardBackground, width: 1.5)),
            )),
    ]);
  }
}
