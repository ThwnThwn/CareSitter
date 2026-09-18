import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/features/settings/data/models/caregiver_review_model.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.read(dioClientProvider));
});

class SettingsRepository {
  final DioClient _dio;

  const SettingsRepository(this._dio);

  Future<List<CaregiverReviewModel>> getCaregiverReviews(
    String caregiverId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reviews/caregiver/$caregiverId',
    );
    final items = response.data?['items'];
    return (items is List ? items : const [])
        .whereType<Map<String, dynamic>>()
        .map(CaregiverReviewModel.fromJson)
        .toList(growable: false);
  }

  Future<String> uploadSupportAttachment(XFile file) async {
    final response = await _dio.postForm<Map<String, dynamic>>(
      '/media/upload',
      FormData.fromMap({
        'file': MultipartFile.fromBytes(
          await file.readAsBytes(),
          filename: file.name,
        ),
        'folder': 'support',
      }),
    );
    final url = response.data?['url']?.toString().trim();
    if (url == null || url.isEmpty) {
      throw const AppApiException(
        message: 'Máy chủ không trả về URL tệp đính kèm.',
      );
    }
    return url;
  }

  Future<String?> createSupportTicket({
    required String title,
    required String description,
    required List<String> attachmentUrls,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/support/tickets',
      data: {
        'type': 'GENERAL',
        'priority': 'MEDIUM',
        'title': title.trim(),
        'description': description.trim(),
        'attachmentUrls': attachmentUrls,
      },
    );
    return response.data?['id']?.toString();
  }
}
