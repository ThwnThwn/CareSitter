import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../review/data/review_repository.dart';
import '../data/booking_repository.dart';
import '../data/models/booking_model.dart';

export '../data/booking_repository.dart' show BookingDraft;
export '../data/models/booking_model.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final bookingStoreProvider =
    NotifierProvider<BookingStore, List<BookingModel>>(BookingStore.new);

/// BookingStore — quản lý state danh sách booking của customer.
/// Luôn dùng backend API thật.
class BookingStore extends Notifier<List<BookingModel>> {
  BookingRepository get _repo => ref.read(bookingRepositoryProvider);

  @override
  List<BookingModel> build() {
    ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth) {
        _loadFromApi();
      } else {
        state = const [];
      }
    });
    _loadFromApi();
    return const [];
  }

  /// Fetch danh sách booking từ API và cập nhật state.
  Future<void> refresh() => _loadFromApi();

  Future<void> _loadFromApi() async {
    final isAuth = ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return;
    try {
      final response = await _repo.getBookings(pageSize: 50);
      state = response.items;
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] Lỗi load bookings: $e');
    }
  }

  // ── Lifecycle actions (gọi trực tiếp API, chờ response) ──────────────────

  Future<BookingModel> createBooking(BookingDraft draft) async {
    var created = await _repo.createBooking(draft);
    if (!draft.isSystemMatched && draft.caregiverId != null) {
      created = await _repo.selectCaregiver(
        created.id,
        caregiverId: draft.caregiverId!,
      );
    }
    final confirmed = await _repo.confirmPayment(created.id);
    state = [confirmed, ...state];
    return confirmed;
  }

  Future<void> caregiverEnRoute(String bookingId) async {
    try {
      final updated = await _repo.startEnRoute(bookingId);
      _applyUpdate(updated);
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] caregiverEnRoute error: $e');
    }
  }

  Future<void> caregiverCheckIn(
    String bookingId, {
    double latitude = 10.7769,
    double longitude = 106.6952,
  }) async {
    try {
      final updated = await _repo.checkIn(bookingId,
          latitude: latitude, longitude: longitude);
      _applyUpdate(updated);
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] caregiverCheckIn error: $e');
    }
  }

  Future<void> caregiverRequestCheckout(String bookingId) async {
    try {
      final updated = await _repo.requestCheckout(bookingId);
      _applyUpdate(updated);
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] requestCheckout error: $e');
    }
  }

  Future<void> confirmPayment(String bookingId) async {
    try {
      final updated = await _repo.confirmPayment(bookingId);
      _applyUpdate(updated);
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] confirmPayment error: $e');
      rethrow;
    }
  }

  Future<void> confirmCompleted(String bookingId) async {
    try {
      final updated = await _repo.completeBooking(bookingId);
      _applyUpdate(updated);
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] confirmCompleted error: $e');
    }
  }

  Future<void> cancel(String bookingId, {String? reason}) async {
    try {
      await _repo.cancelBooking(bookingId, reason: reason);
      // Cập nhật status local để UI phản hồi ngay
      _updateStatus(bookingId, 'cancelled');
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] cancel error: $e');
    }
  }

  Future<void> openDispute(String bookingId, String reason,
      {String? description}) async {
    try {
      await ref.read(reviewRepositoryProvider).createDispute(
            bookingId: bookingId,
            reason: reason,
            description: description ?? reason,
          );
      state = [
        for (final b in state)
          if (b.id == bookingId)
            b.copyWith(status: 'disputed', cancelReason: reason)
          else
            b,
      ];
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] openDispute error: $e');
      rethrow;
    }
  }

  Future<void> markReviewed(
    String bookingId, {
    String? caregiverId,
    int? rating,
    String? comment,
    String? experienceTags,
  }) async {
    try {
      if (caregiverId != null && rating != null && rating > 0) {
        await ref.read(reviewRepositoryProvider).createReview(
              bookingId: bookingId,
              caregiverId: caregiverId,
              rating: rating,
              comment: comment,
              experienceTags: experienceTags,
            );
      }
      state = [
        for (final b in state)
          if (b.id == bookingId) b.copyWith(isReviewed: true) else b,
      ];
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] markReviewed error: $e');
      state = [
        for (final b in state)
          if (b.id == bookingId) b.copyWith(isReviewed: true) else b,
      ];
      rethrow;
    }
  }

  void toggleTask(String bookingId, int taskIndex) {
    state = [
      for (final b in state)
        if (b.id == bookingId)
          b.copyWith(
            tasks: [
              for (int i = 0; i < b.tasks.length; i++)
                if (i == taskIndex) _toggleTaskItem(b.tasks[i]) else b.tasks[i],
            ],
          )
        else
          b,
    ];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  dynamic _toggleTaskItem(dynamic task) {
    try {
      final isCompleted = task.isCompleted == true;
      return task.copyWith(isCompleted: !isCompleted);
    } catch (_) {
      return task;
    }
  }

  void _applyUpdate(BookingModel updated) {
    state = [
      for (final b in state)
        if (b.id == updated.id) updated else b,
    ];
  }

  void _updateStatus(String id, String newStatus) {
    state = [
      for (final b in state)
        if (b.id == id) b.copyWith(status: newStatus) else b,
    ];
  }
}
