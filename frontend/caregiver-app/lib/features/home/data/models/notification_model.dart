import 'dart:convert';

class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final String time;
  final String type;
  final bool isRead;
  final String? deepLink;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    required this.isRead,
    this.deepLink,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
            DateTime.now();
    final data = _decodeData(json['data']);
    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Thông báo',
      body: json['body']?.toString() ?? '',
      time: _relativeTime(createdAt),
      type: json['type']?.toString() ?? 'system',
      isRead: json['readAt'] != null,
      deepLink: data['deepLink']?.toString(),
    );
  }

  AppNotificationModel copyWith({bool? isRead}) {
    return AppNotificationModel(
      id: id,
      title: title,
      body: body,
      time: time,
      type: type,
      isRead: isRead ?? this.isRead,
      deepLink: deepLink,
    );
  }

  static Map<String, dynamic> _decodeData(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return const {};
  }

  static String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${value.day}/${value.month}/${value.year}';
  }
}
