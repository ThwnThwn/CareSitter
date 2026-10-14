import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App composition supplies routing; core and feature UI depend on this port.
final notificationDeepLinkServiceProvider = Provider<NotificationDeepLinkService>(
  (_) => throw StateError('Notification navigation must be configured by the app.'),
);

abstract interface class NotificationDeepLinkService {
  String? resolveRoute(Map<String, dynamic> data);
  Future<void> handle(Map<String, dynamic> data, {String? deliveryId});
  Future<void> flushPending();
  void showForeground(
      {required String title,
      required String body,
      required Map<String, dynamic> data,
      String? deliveryId});
}
