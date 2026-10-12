import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class NotificationsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  const NotificationsAppBar(
      {super.key, required this.unreadCount, required this.ref});
  final int unreadCount;
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông báo',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppFontSizes.s17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (unreadCount > 0)
              Text(
                '$unreadCount chưa đọc',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: AppFontSizes.s12,
                ),
              ),
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationsProvider.notifier)
                  .markAllRead()
                  .catchError((_) {}),
              child: const Text(
                'Đọc tất cả',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      );
}
