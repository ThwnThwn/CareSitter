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
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: () {
              notifier.markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã đánh dấu đọc toàn bộ thông báo'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              'Đọc tất cả',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: list.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 64, color: AppColors.textHint),
                  SizedBox(height: 16),
                  Text(
                    'Không có thông báo nào',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
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
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: iconData['bg'] as Color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData['icon'] as IconData,
                            color: iconData['color'] as Color),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontWeight:
                                    isRead ? FontWeight.w500 : FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            notif.body,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notif.time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
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
