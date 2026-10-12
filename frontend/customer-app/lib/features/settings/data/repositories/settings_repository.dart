import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/features/settings/data/models/notification_preferences.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.read(dioClientProvider)),
);

class SettingsRepository {
  final DioClient _dio;

  const SettingsRepository(this._dio);

  Future<NotificationPrefs> getNotificationPreferences(
      {ApiCancellation? cancellation}) async {
    final response = await _dio.getCancelable<Map<String, dynamic>>(
      '/profile/notification-preferences',
      cancelToken: (cancellation ?? ApiCancellation()).transportToken,
    );
    return response.data == null
        ? const NotificationPrefs()
        : NotificationPrefs.fromJson(response.data!);
  }

  Future<void> saveNotificationPreferences(NotificationPrefs preferences,
      {ApiCancellation? cancellation}) async {
    await _dio.putCancelable<void>('/profile/notification-preferences',
        cancelToken: (cancellation ?? ApiCancellation()).transportToken,
        data: {
          'bookingUpdates': preferences.bookingUpdates,
          'paymentUpdates': preferences.paymentUpdates,
          'caregiverArriving': preferences.caregiverArriving,
          'scheduleReminder': preferences.scheduleReminder,
          'chatMessage': preferences.chatMessage,
          'promotion': preferences.promotion,
        });
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/profile/password',
      data: {
        'CurrentPassword': currentPassword,
        'NewPassword': newPassword,
      },
    );
    return response.statusCode == 200;
  }
}
