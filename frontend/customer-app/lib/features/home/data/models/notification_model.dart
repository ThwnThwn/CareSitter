import 'dart:convert';

import 'notification_chat_model.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  final int unreadCount;
  final String source;
  final String? groupKey;
  final NotificationChatModel? chat;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.data,
    required bool isRead,
    int? unreadCount,
    this.source = 'backend',
    this.groupKey,
    this.chat,
  }) : unreadCount = unreadCount ?? (isRead ? 0 : 1);

  String get key => groupKey ?? id;
  bool get isRead => unreadCount <= 0;
  bool get isBookingChat => type == 'BOOKING_CHAT';
  bool get isSupportChat => type == 'SUPPORT_CHAT';
  bool get isChat => isBookingChat || isSupportChat;
  bool get isLocal => source == 'console_local';
  DateTime get timestamp => chat?.sentAt ?? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'INFO',
        title: json['title']?.toString() ?? 'Thông báo',
        body: json['body']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
        data: _decodeData(json['data']),
        isRead: json['readAt'] != null,
        unreadCount: (json['unreadCount'] as num?)?.toInt(),
        groupKey: json['groupKey'] as String?,
        chat: json['chat'] is Map<String, dynamic>
            ? NotificationChatModel.fromJson(
                json['chat'] as Map<String, dynamic>)
            : null,
      );

  AppNotification markRead() => AppNotification(
        id: id,
        source: source,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        data: data,
        isRead: true,
        groupKey: groupKey,
        chat: chat,
      );

  static Map<String, dynamic> _decodeData(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Một payload lỗi không được làm ẩn toàn bộ notification inbox.
      }
    }
    return const {};
  }
}
