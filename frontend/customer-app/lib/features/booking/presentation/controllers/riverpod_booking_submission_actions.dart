import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'booking_controller.dart';
import 'booking_submission_actions.dart';
import 'self_recipient_controller.dart';

class RiverpodBookingSubmissionActions implements BookingSubmissionActions {
  RiverpodBookingSubmissionActions(this.ref);
  final Ref ref;
  @override
  Future<({BeneficiaryModel profile, bool needsReview})> resolveSelf(
          String addressId) =>
      ref.read(selfRecipientProvider.notifier).resolve(addressId);
  @override
  bool get selfComplete =>
      ref.read(selfRecipientProvider).requireValue.isComplete;
  @override
  void publishSelf(BeneficiaryModel profile) {
    ref.invalidate(bookingRecipientsProvider);
    ref.read(beneficiaryStoreProvider.notifier).acceptSaved(profile);
  }

  @override
  void reloadSelf() => ref.read(selfRecipientProvider.notifier).load();
  @override
  Future<BookingModel> createBooking(BookingDraft draft) =>
      ref.read(bookingStoreProvider.notifier).createBooking(draft);
  @override
  Future<BookingListResponse> getBookings(
          {required int page, required int pageSize}) =>
      ref
          .read(bookingStoreProvider.notifier)
          .getBookings(page: page, pageSize: pageSize);
}
