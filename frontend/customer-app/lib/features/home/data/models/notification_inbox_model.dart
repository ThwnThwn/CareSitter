import 'notification_model.dart';

class NotificationInboxModel {
  const NotificationInboxModel({
    this.items = const [],
    this.unreadCount = 0,
    this.hasMore = false,
    this.page = 1,
    this.version,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final bool hasMore;
  final int page;
  final String? version;

  factory NotificationInboxModel.fromJson(Map<String, dynamic> json, int page) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
    return NotificationInboxModel(
      items: items,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ??
          items.fold(0, (sum, item) => sum + item.unreadCount),
      hasMore: json['hasMore'] == true,
      page: page,
      version: json['version'] as String?,
    );
  }

  NotificationInboxModel copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? hasMore,
  }) =>
      NotificationInboxModel(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
        hasMore: hasMore ?? this.hasMore,
        page: page,
        version: version,
      );
}
