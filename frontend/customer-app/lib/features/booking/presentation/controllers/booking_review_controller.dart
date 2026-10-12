import '../../../review/data/repositories/review_repository.dart';
import 'booking_state_controller.dart';

class BookingReviewController {
  BookingReviewController(this.repository, this.store);
  final ReviewRepository repository;
  final BookingStateController store;
  Future<void> dispute(String id, String reason, {String? description}) async {
    if (!store.active) return;
    await repository.createDispute(
        bookingId: id, reason: reason, description: description ?? reason);
    store.replace([
      for (final item in store.items)
        if (item.id == id)
          item.copyWith(status: 'disputed', cancelReason: reason)
        else
          item
    ]);
  }

  Future<void> review(String id,
      {String? caregiverId,
      int? rating,
      String? comment,
      String? experienceTags}) async {
    if (!store.active) return;
    try {
      if (caregiverId != null && rating != null && rating > 0) {
        await repository.createReview(
            bookingId: id,
            caregiverId: caregiverId,
            rating: rating,
            comment: comment,
            experienceTags: experienceTags);
      }
      _markReviewed(id);
    } catch (_) {
      // Giữ hành vi cache hiện có; đối soát review thuộc luồng riêng.
      _markReviewed(id);
      rethrow;
    }
  }

  void _markReviewed(String id) => store.replace([
        for (final item in store.items)
          if (item.id == id) item.copyWith(isReviewed: true) else item
      ]);
}
