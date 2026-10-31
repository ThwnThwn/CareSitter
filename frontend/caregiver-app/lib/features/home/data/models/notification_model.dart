import 'dart:convert';

class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final String type;
  final bool isRead;
  final String? deepLink;
  final String? status;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    required this.isRead,
    this.deepLink,
    this.status,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final data = _decodeData(json['data']);
    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Thông báo',
      body: json['body']?.toString() ?? '',
      createdAt: createdAt,
      type: json['type']?.toString() ?? 'system',
      isRead: json['readAt'] != null,
      deepLink: data['deepLink']?.toString(),
      status: data['status']?.toString(),
    );
  }

  AppNotificationModel copyWith({bool? isRead}) {
    return AppNotificationModel(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      type: type,
      isRead: isRead ?? this.isRead,
      deepLink: deepLink,
      status: status,
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
}
