import '../models/recovery_grant_model.dart';
export '../models/recovery_grant_model.dart';
import '../models/recovery_challenge_model.dart';
export '../models/recovery_challenge_model.dart';
import 'package:caregiver_app/features/auth/data/models/recovery_email_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/error/app_exception.dart';

final recoveryRepositoryProvider = Provider<RecoveryRepository>(
  (ref) => RecoveryRepository(ref.read(dioClientProvider)),
);

class RecoveryRepository {
  RecoveryRepository(this.client);
  final DioClient client;
  Future<RecoveryChallenge> request(String email) async {
    final response = await client.post<Map<String, dynamic>>(
        '/auth/password-recovery/request',
        data: {'email': email.trim().toLowerCase()});
    return RecoveryChallenge.fromJson(response.data!);
  }

  Future<RecoveryGrant> verify(String challengeId, String code) async {
    final response = await client.post<Map<String, dynamic>>(
        '/auth/password-recovery/verify',
        data: {'challengeId': challengeId, 'code': code});
    return RecoveryGrant(response.data!['resetToken'] as String,
        (response.data!['expiresIn'] as num).toInt());
  }

  Future<void> reset(String token, String password, String confirmation) async {
    await client.post<dynamic>('/auth/password-recovery/reset', data: {
      'resetToken': token,
      'newPassword': password,
      'confirmPassword': confirmation
    });
  }

  Future<Map<String, dynamic>> profile() async =>
      (await client.get<Map<String, dynamic>>('/profile')).data!;
  Future<RecoveryEmailModel> emailProfile() async =>
      RecoveryEmailModel.fromJson(await profile());
  Future<RecoveryChallenge> requestEmail(String email, String? password) async {
    final response = await client
        .post<Map<String, dynamic>>('/profile/recovery-email/request', data: {
      'newEmail': email.trim().toLowerCase(),
      'currentPassword': password
    });
    return RecoveryChallenge.fromJson(response.data!);
  }

  Future<Map<String, dynamic>> confirmEmail(
          String challengeId, String code) async =>
      (await client.post<Map<String, dynamic>>(
              '/profile/recovery-email/confirm',
              data: {'challengeId': challengeId, 'code': code}))
          .data!;
  Future<RecoveryEmailModel> confirmEmailProfile(
          String id, String code) async =>
      RecoveryEmailModel.fromJson(await confirmEmail(id, code));
}

String recoveryError(Object error) {
  if (error is AppApiException) return error.message;
  if (error is DioException) {
    if (error.error is AppApiException) {
      return (error.error as AppApiException).message;
    }
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    if (error.response?.statusCode == 429) {
      return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.';
    }
    return 'Không thể kết nối. Kiểm tra mạng và thử lại.';
  }
  return 'Chưa hoàn tất yêu cầu. Vui lòng thử lại.';
}
