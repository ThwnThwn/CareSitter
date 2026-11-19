import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/auth/auth_session_scope.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_quote_model.dart';
import 'package:caresitter_customer/features/promotions/data/repositories/promotion_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'booking_promotion_state.dart';
import 'booking_wizard_state.dart';

final bookingPromotionProvider = AutoDisposeNotifierProvider.family<
    BookingPromotionController,
    BookingPromotionState,
    BookingWizardArgs>(BookingPromotionController.new);

const _previewUnavailable = 'Chưa kiểm tra được mã ưu đãi. Vui lòng thử lại.';

class BookingPromotionController extends AutoDisposeFamilyNotifier<
    BookingPromotionState, BookingWizardArgs> {
  late AuthSessionScope _session;
  ApiCancellation? _request;
  static const maxCodeLength = 50;

  @override
  BookingPromotionState build(BookingWizardArgs arg) {
    _session = AuthSessionScope.watch(ref);
    ref.onDispose(_cancelRequest);
    return const BookingPromotionState();
  }

  void setCode(String code) {
    if (state.code == code) return;
    _cancelRequest();
    state = BookingPromotionState(code: code);
  }

  void requireReapply(String message) {
    if (!state.hasCode && !state.checking) return;
    _cancelRequest();
    state = BookingPromotionState(
        code: state.code, error: state.hasCode ? message : null);
  }

  Future<String?> apply(PromotionBookingSlot slot,
      {String? candidateCode}) async {
    final session = _session;
    if (!session.isCurrent || state.checking) return _previewUnavailable;
    final previous = state;
    final input = candidateCode ?? previous.code;
    final code = input.trim().toUpperCase();
    if (code.isEmpty) return 'Vui lòng nhập mã ưu đãi.';
    if (code.length > maxCodeLength) {
      const message = 'Mã ưu đãi chỉ được tối đa $maxCodeLength ký tự.';
      if (candidateCode == null) requireReapply(message);
      return message;
    }

    final request = ApiCancellation();
    _request = request;
    bool current() => identical(_request, request) && session.isCurrent;
    state = previous.withChecking(true);
    String fail(String message) {
      if (current()) {
        state = candidateCode == null
            ? BookingPromotionState(code: input, error: message)
            : previous;
      }
      return message;
    }

    try {
      final quote = await ref
          .read(promotionRepositoryProvider)
          .preview(code, slot, request);
      if (!current()) return _previewUnavailable;
      state = BookingPromotionState(code: quote.code, quote: quote, slot: slot);
      return null;
    } on AppApiException catch (error) {
      return fail(error.isCancelled ? _previewUnavailable : error.message);
    } on FormatException {
      return fail(_previewUnavailable);
    } finally {
      if (identical(_request, request)) _request = null;
    }
  }

  void cancelPreview() {
    if (!state.checking) return;
    _cancelRequest();
    state = state.withChecking(false);
  }

  void _cancelRequest() {
    _request?.cancel();
    _request = null;
  }
}
