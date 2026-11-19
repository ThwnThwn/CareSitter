class NotificationChatModel {
  const NotificationChatModel({
    this.senderName,
    this.senderAvatarUrl,
    this.preview,
    this.sentAt,
    this.scheduledStart,
  });

  final String? senderName;
  final String? senderAvatarUrl;
  final String? preview;
  final DateTime? sentAt;
  final DateTime? scheduledStart;

  factory NotificationChatModel.fromJson(Map<String, dynamic> json) =>
      NotificationChatModel(
        senderName: _text(json['senderName']),
        senderAvatarUrl: _text(json['senderAvatarUrl']),
        preview: _text(json['preview']),
        sentAt: _date(json['sentAt']),
        scheduledStart: _date(json['scheduledStart']),
      );

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
