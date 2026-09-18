import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/settings/data/models/notification_preferences.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.read(dioClientProvider)),
);

class SettingsRepository {
  final DioClient _dio;

  const SettingsRepository(this._dio);

  Future<NotificationPrefs> getNotificationPreferences() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/profile/notification-preferences',
    );
    return response.data == null
        ? const NotificationPrefs()
        : NotificationPrefs.fromJson(response.data!);
  }

  Future<void> saveNotificationPreferences(
      NotificationPrefs preferences) async {
    await _dio.put<void>('/profile/notification-preferences', data: {
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
