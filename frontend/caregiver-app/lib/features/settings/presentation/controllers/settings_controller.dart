import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/features/settings/data/models/caregiver_review_model.dart';
import 'package:caregiver_app/features/settings/data/repositories/settings_repository.dart';

final settingsControllerProvider =
    Provider((ref) => SettingsController(ref.read(settingsRepositoryProvider)));

class SettingsController {
  const SettingsController(this._repository);
  final SettingsRepository _repository;
  Future<List<CaregiverReviewModel>> getCaregiverReviews(String id) =>
      _repository.getCaregiverReviews(id);
  Future<String> uploadSupportAttachment(XFile file,
          {ApiCancellation? cancellation}) =>
      _repository.uploadSupportAttachment(file, cancellation: cancellation);
  Future<String?> createSupportTicket(
          {required String title,
          required String description,
          required List<String> attachmentUrls,
          ApiCancellation? cancellation}) =>
      _repository.createSupportTicket(
          title: title,
          description: description,
          attachmentUrls: attachmentUrls,
          cancellation: cancellation);
}
