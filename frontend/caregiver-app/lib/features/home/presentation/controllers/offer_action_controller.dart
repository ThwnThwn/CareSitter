import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';

enum OfferActionResult { success, failed, ignored }

final offerActionControllerProvider =
    StateNotifierProvider.autoDispose<OfferActionController, String?>((ref) {
  ref.watch(authStateProvider.select(
      (session) => (session.value?.userId, session.value?.isAuthenticated)));
  return OfferActionController();
});

class OfferActionController extends StateNotifier<String?> {
  OfferActionController() : super(null);

  Future<OfferActionResult> run(
      String bookingId, Future<void> Function() action) async {
    if (!mounted || state != null) return OfferActionResult.ignored;
    state = bookingId;
    try {
      await action();
      return mounted ? OfferActionResult.success : OfferActionResult.ignored;
    } catch (_) {
      return mounted ? OfferActionResult.failed : OfferActionResult.ignored;
    } finally {
      if (mounted) state = null;
    }
  }
}
