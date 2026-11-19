import 'package:cached_network_image/cached_network_image.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';
import 'notifications_presentation_helpers.dart';

class NotificationItemDetails extends StatelessWidget {
  const NotificationItemDetails({
    super.key,
    required this.notification,
    required this.now,
    required this.iconColor,
    required this.icon,
  });

  final AppNotification notification;
  final DateTime now;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final item = notification;
    final title = item.chat?.senderName ??
        (item.isBookingChat
            ? 'Tin nhắn về lịch chăm sóc'
            : item.isSupportChat
                ? 'Hỗ trợ CareSitter'
                : item.title);
    final body = item.isChat ? item.chat?.preview : item.body;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!item.isRead)
                    const Padding(
                      padding: EdgeInsetsDirectional.only(end: AppSpacing.xs),
                      child: SizedBox.square(
                        dimension: 7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppFontSizes.s15,
                        fontWeight:
                            item.isRead ? FontWeight.w600 : FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (body != null && body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.s14,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _NotificationMetadata(item: item, now: now),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar() {
    final name = notification.chat?.senderName;
    final words = name?.split(RegExp(r'\s+')) ?? const <String>[];
    final initials = words.isEmpty || !notification.isBookingChat
        ? null
        : (words.length == 1
                ? words.first.characters.first
                : '${words.first.characters.first}${words.last.characters.first}')
            .toUpperCase();
    final fallback = ColoredBox(
      color:
          notification.isRead ? AppColors.primaryContainer : AppColors.surface,
      child: Center(
        child: initials == null
            ? Icon(icon, color: iconColor, size: 20)
            : Text(
                initials,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
    final url = notification.chat?.senderAvatarUrl;
    final image =
        url != null && (url.startsWith('https://') || url.startsWith('http://'))
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback;
    return ExcludeSemantics(
      child: SizedBox.square(dimension: 42, child: ClipOval(child: image)),
    );
  }
}

class _NotificationMetadata extends StatelessWidget {
  const _NotificationMetadata({required this.item, required this.now});

  final AppNotification item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final booking = notificationBookingLabel(item);
    const style = TextStyle(
      color: AppColors.textSecondary,
      fontSize: AppFontSizes.s12,
    );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (booking != null) Text(booking, style: style),
        Text(notificationTimestamp(item.timestamp, now), style: style),
        if (!item.isRead)
          Text(
            item.unreadCount == 1 ? 'Chưa đọc' : '${item.unreadCount} chưa đọc',
            style: style.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
