import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';
import '../models/notification_inbox_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.read(dioClientProvider)),
);

class NotificationRepository {
  final DioClient _dio;

  const NotificationRepository(this._dio);

  Future<NotificationInboxModel> getNotifications(
      {int page = 1, CancelToken? cancelToken}) async {
    final response = await _dio.getCancelable<Map<String, dynamic>>(
      '/notifications/inbox',
      query: {'page': page, 'pageSize': 50},
      cancelToken: cancelToken ?? CancelToken(),
    );
    return NotificationInboxModel.fromJson(response.data ?? const {}, page);
  }

  Future<void> markAllRead() async {
    await _dio.put<void>('/notifications/read-all');
  }

  Future<void> markRead(String id) async {
    await _dio.put<void>('/notifications/$id/read-group');
  }
}
