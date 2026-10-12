import '../../../beneficiary/data/models/beneficiary_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/booking_draft.dart';

abstract interface class BookingSubmissionActions {
  Future<({BeneficiaryModel profile, bool needsReview})> resolveSelf(
      String addressId);
  bool get selfComplete;
  void publishSelf(BeneficiaryModel profile);
  void reloadSelf();
  Future<BookingModel> createBooking(BookingDraft draft);
  Future<BookingListResponse> getBookings(
      {required int page, required int pageSize});
}
