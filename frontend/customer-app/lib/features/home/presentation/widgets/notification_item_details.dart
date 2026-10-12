import 'package:caresitter_customer/features/home/presentation/widgets/notifications_presentation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class NotificationItemDetails extends StatelessWidget {
  const NotificationItemDetails(
      {super.key,
      required this.iconColor,
      required this.icon,
      required this.notification,
      required this.route});
  final Color iconColor;
  final IconData icon;
  final AppNotification notification;
  final String? route;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.s14,
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(
                            left: AppSpacing.sm, top: AppSpacing.xs),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.tiny),
                Text(
                  notification.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.s13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  notificationsRelativeTime(notification.createdAt),
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: AppFontSizes.s11,
                  ),
                ),
              ],
            ),
          ),
          if (route?.isNotEmpty == true)
            const Padding(
              padding:
                  EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.control),
              child: Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size: 18,
              ),
            ),
        ],
      );
}
