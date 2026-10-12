import 'package:caregiver_app/features/home/presentation/widgets/notification_title.dart';
import 'package:caregiver_app/features/home/presentation/widgets/notification_body.dart';
import 'package:caregiver_app/features/home/presentation/widgets/notifications_app_bar.dart';
import 'package:caregiver_app/features/home/presentation/widgets/notifications_empty_state.dart';
import 'package:caregiver_app/features/home/presentation/widgets/notification_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/push/notification_deep_link_service.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/home/presentation/controllers/notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: NotificationsAppBar(callbackAction1: () {
        notifier.markAllAsRead();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu đọc toàn bộ thông báo'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }),
      body: list.isEmpty
          ? const NotificationsEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final notif = list[index];
                final isRead = notif.isRead;
                final iconData = _getIconForType(notif.type);

                return Container(
                  color: isRead
                      ? Colors.transparent
                      : AppColors.primary.withValues(alpha: 0.04),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      leading: NotificationIcon(iconData: iconData),
                      title: NotificationTitle(notif: notif, isRead: isRead),
                      subtitle: NotificationBody(notif: notif),
                      onTap: () {
                        notifier.markAsRead(notif.id);
                        ref.read(notificationDeepLinkServiceProvider).handle({
                          'type': notif.type,
                          if (notif.deepLink != null)
                            'deepLink': notif.deepLink,
                        });
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  Map<String, dynamic> _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'SHIFT':
      case 'CARE_TIMELINE':
        return {
          'icon': Icons.directions_run_rounded,
          'bg': AppColors.primaryContainer,
          'color': AppColors.primary,
        };
      case 'BOOKING':
      case 'BOOKING_OFFER':
      case 'MATCHING_FAILED':
        return {
          'icon': Icons.calendar_month_rounded,
          'bg': AppColors.secondaryContainer,
          'color': AppColors.secondaryStrong,
        };
      case 'PAYMENT':
      case 'PAYOUT':
        return {
          'icon': Icons.account_balance_wallet_rounded,
          'bg': AppColors.infoLight,
          'color': AppColors.info,
        };
      case 'SOS':
        return {
          'icon': Icons.sos_rounded,
          'bg': AppColors.errorLight,
          'color': AppColors.error,
        };
      default:
        return {
          'icon': Icons.notifications_rounded,
          'bg': AppColors.surfaceVariant,
          'color': AppColors.textSecondary,
        };
    }
  }
}
