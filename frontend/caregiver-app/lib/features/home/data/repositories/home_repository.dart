import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/features/home/data/models/notification_model.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.read(dioClientProvider));
});

class HomeRepository {
  final DioClient _dio;

  const HomeRepository(this._dio);

  Future<List<AppNotificationModel>> getNotifications() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      query: {'pageSize': 50},
    );
    return (response.data?['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotificationModel.fromJson)
        .toList(growable: false);
  }

  Future<void> markAllNotificationsAsRead() {
    return _dio.put<void>('/notifications/read-all').then((_) {});
  }

  Future<void> markNotificationAsRead(String id) {
    return _dio.put<void>('/notifications/$id/read').then((_) {});
  }
}
