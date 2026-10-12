import 'package:caresitter_customer/features/home/presentation/widgets/notifications_app_bar.dart';
export 'package:caresitter_customer/features/home/presentation/widgets/notifications_presentation_helpers.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/notifications_notification_item.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/notifications_notification_load_error.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/notifications_notification_empty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.valueOrNull
            ?.where((notification) => !notification.isRead)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NotificationsAppBar(unreadCount: unreadCount, ref: ref),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NotificationsNotificationLoadError(
          onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (items) => items.isEmpty
            ? const NotificationsNotificationEmpty()
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(notificationsProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: AppColors.divider,
                  ),
                  itemBuilder: (context, index) => FadeSlideStaggered(
                    index: index,
                    child: NotificationsNotificationItem(
                        notification: items[index]),
                  ),
                ),
              ),
      ),
    );
  }
}
