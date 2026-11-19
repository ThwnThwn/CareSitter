import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../data/models/notification_inbox_model.dart';
import '../../data/models/notification_model.dart';
import 'notifications_notification_empty.dart';
import 'notifications_notification_item.dart';
import 'notifications_presentation_helpers.dart';

class NotificationInboxList extends StatelessWidget {
  const NotificationInboxList({
    super.key,
    required this.snapshot,
    required this.onRefresh,
    required this.onMarkAll,
    required this.onLoadMore,
    required this.onOpen,
    required this.onMarkRead,
  });

  final NotificationInboxModel snapshot;
  final Future<void> Function() onRefresh;
  final VoidCallback? onMarkAll;
  final VoidCallback? onLoadMore;
  final ValueChanged<AppNotification> onOpen;
  final Future<void> Function(AppNotification) onMarkRead;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sections = notificationSections(snapshot.items, now);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: sections.isEmpty
          ? const CustomScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: NotificationsNotificationEmpty(),
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
              children: [
                if (snapshot.unreadCount > 0) _toolbar(),
                for (final section in sections.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xs,
                        AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
                    child: Semantics(
                      header: true,
                      child: Text(section.key,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                  for (final item in section.value)
                    Padding(
                      key: ValueKey(item.key),
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: NotificationsNotificationItem(
                        notification: item,
                        now: now,
                        onOpen: () => onOpen(item),
                        onMarkRead: () => onMarkRead(item),
                      ),
                    ),
                ],
                if (snapshot.hasMore)
                  Center(
                    child: TextButton(
                      onPressed: onLoadMore,
                      child: Text(onLoadMore == null
                          ? 'Đang tải…'
                          : 'Xem thông báo cũ hơn'),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _toolbar() => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text(
            '${snapshot.unreadCount} thông báo chưa đọc',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w600,
            ),
          ),
          OutlinedButton.icon(
            onPressed: onMarkAll,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.compact),
            ),
            icon: const Icon(Icons.done_all_rounded, size: 19),
            label: Text(onMarkAll == null ? 'Đang đánh dấu…' : 'Đọc tất cả'),
          ),
        ],
      );
}
