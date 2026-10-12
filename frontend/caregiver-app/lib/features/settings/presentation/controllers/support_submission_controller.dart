import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/error/failure.dart';
import 'package:caregiver_app/features/settings/presentation/controllers/settings_controller.dart';

sealed class SupportSubmitResult {
  const SupportSubmitResult();
}

final class SupportSubmitted extends SupportSubmitResult {
  const SupportSubmitted(this.ticketId);
  final String? ticketId;
}

final class SupportFailed extends SupportSubmitResult {
  const SupportFailed(this.message);
  final String message;
}

final class SupportIgnored extends SupportSubmitResult {
  const SupportIgnored();
}

final supportSubmissionControllerProvider =
    StateNotifierProvider.autoDispose<SupportSubmissionController, bool>((ref) {
  ref.watch(authStateProvider.select(
      (session) => (session.value?.userId, session.value?.isAuthenticated)));
  return SupportSubmissionController(ref.read(settingsControllerProvider));
});

class SupportSubmissionController extends StateNotifier<bool> {
  SupportSubmissionController(this.actions) : super(false);
  final SettingsController actions;
  ApiCancellation? _cancellation;

  Future<SupportSubmitResult> submit(
      String title, String description, List<XFile> attachments) async {
    if (!mounted || state) return const SupportIgnored();
    state = true;
    final cancellation = _cancellation = ApiCancellation();
    final files = List<XFile>.of(attachments);
    try {
      final urls = <String>[];
      for (final file in files) {
        urls.add(await actions.uploadSupportAttachment(file,
            cancellation: cancellation));
        if (!mounted) return const SupportIgnored();
      }
      final id = await actions.createSupportTicket(
          title: title,
          description: description,
          attachmentUrls: urls,
          cancellation: cancellation);
      return mounted ? SupportSubmitted(id) : const SupportIgnored();
    } catch (error) {
      return mounted
          ? SupportFailed(apiErrorMessage(error))
          : const SupportIgnored();
    } finally {
      if (mounted) {
        state = false;
        _cancellation = null;
      }
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }
}
