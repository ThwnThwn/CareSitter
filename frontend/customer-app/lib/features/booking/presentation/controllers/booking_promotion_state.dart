import 'package:caresitter_customer/features/promotions/data/models/promotion_quote_model.dart';

class BookingPromotionState {
  const BookingPromotionState({
    this.code = '',
    this.quote,
    this.slot,
    this.checking = false,
    this.error,
  });

  final String code;
  final PromotionQuoteModel? quote;
  final PromotionBookingSlot? slot;
  final bool checking;
  final String? error;

  bool get hasCode => code.trim().isNotEmpty;

  PromotionQuoteModel? quoteFor(PromotionBookingSlot? bookingSlot) =>
      bookingSlot != null && slot == bookingSlot ? quote : null;

  bool canSubmitFor(PromotionBookingSlot? bookingSlot) =>
      !checking && (!hasCode || quoteFor(bookingSlot) != null);

  BookingPromotionState withChecking(bool value) => BookingPromotionState(
      code: code, quote: quote, slot: slot, checking: value, error: error);
}
