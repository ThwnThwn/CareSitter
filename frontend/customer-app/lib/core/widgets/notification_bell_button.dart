import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = unreadCount > 0
        ? 'Thông báo, $unreadCount thông báo chưa đọc'
        : 'Thông báo';

    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticsLabel,
        child: SizedBox.square(
          dimension: 40,
          child: Material(
            color: AppColors.background,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                  if (unreadCount > 0)
                    const Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        key: Key('notification-unread-indicator'),
                        radius: 4,
                        backgroundColor: AppColors.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
