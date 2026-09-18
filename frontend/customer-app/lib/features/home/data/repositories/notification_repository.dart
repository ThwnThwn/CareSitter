import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/home/data/models/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.read(dioClientProvider)),
);

class NotificationRepository {
  final DioClient _dio;

  const NotificationRepository(this._dio);

  Future<List<AppNotification>> getNotifications() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      query: {'pageSize': 50},
    );
    return (response.data?['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  Future<void> markAllRead() async {
    await _dio.put<void>('/notifications/read-all');
  }

  Future<void> markRead(String id) async {
    await _dio.put<void>('/notifications/$id/read');
  }
}
