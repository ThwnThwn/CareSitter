import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/realtime/care_signalr_service.dart';
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

  // ── Sync engine state ───────────────────────────────────────────────────
  int _lastCursor = 0;
  bool _isSyncing = false;
  bool _syncPending = false;

  // Subscription realtime — giữ để cancel khi logout/dispose.
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _realtimeSubscribed = false;

  @override
  List<BookingModel> build() {
    _cancelRealtimeSubscriptions();
    _lastCursor = 0;
    _isSyncing = false;
    _syncPending = false;

    ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth) {
        unawaited(_initializeAuthenticated());
      } else {
        _cancelRealtimeSubscriptions();
        _lastCursor = 0;
        state = const [];
      }
    });

    // ref.onDispose để cancel subscriptions khi provider bị destroy
    ref.onDispose(() {
      _cancelRealtimeSubscriptions();
    });

    unawaited(_initializeAuthenticated());
    return const [];
  }

  Future<void> _initializeAuthenticated() async {
    await _loadFromApi();
    await _startRealtime();
  }

  /// Mở hub rồi mới subscribe. Customer group được server tự join khi connect.
  Future<void> _startRealtime() async {
    final signalR = ref.read(careSignalRProvider);
    await signalR.connect();
    if (!signalR.isConnected || _realtimeSubscribed) return;

    _realtimeSubscribed = true;
    _subscriptions.add(
      signalR.customerSyncStream.listen((_) => requestSync()),
    );
    _subscriptions.add(
      signalR.onReconnected.listen((_) => requestSync()),
    );

    // Bù khoảng thời gian từ lúc initial load đến lúc hub vừa connected.
    unawaited(requestSync());
  }

  void _cancelRealtimeSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _realtimeSubscribed = false;
  }

  /// Fetch toàn bộ booking từ API và cập nhật state.
  /// Gọi khi lần đầu vào hoặc khi `resetRequired == true`.
  Future<void> refresh() => _loadFromApi();

  Future<void> _loadFromApi() async {
    final isAuth = ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return;
    try {
      final response = await _repo.getBookings(pageSize: 50);
      state = response.items;
      // Đặt cursor từ response initial load — dùng làm mốc bắt đầu delta sync.
      _lastCursor = response.syncCursor;
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] Lỗi load bookings: $e');
    }
  }

  // ── Sync engine ──────────────────────────────────────────────────────

  /// Kích hoạt delta sync. Nếu đang sync thì ghi nhớ pendng để chạy sau.
  /// Gọi an toàn nhiều lần liên tiếp — mutex đảm bảo chỉ 1 request active.
  Future<void> requestSync() async {
    if (_isSyncing) {
      _syncPending = true;
      return;
    }
    await _syncUntilCaughtUp();
  }

  Future<void> _syncUntilCaughtUp() async {
    _isSyncing = true;
    try {
      bool hasMore = true;
      while (hasMore) {
        final result = await _repo.syncBookings(_lastCursor);
        if (result.resetRequired) {
          await _loadFromApi(); // full refresh, reset cursor
          return;
        }
        _mergeItems(result.items.cast<BookingModel>());
        _lastCursor = result.nextCursor;
        hasMore = result.hasMore;
      }
    } catch (e) {
      // Lỗi network — giữ cursor cũ, retry tick kế tiếp (silent).
      // ignore: avoid_print
      print('[BookingStore] sync error (cursor=$_lastCursor): $e');
    } finally {
      _isSyncing = false;
      if (_syncPending) {
        _syncPending = false;
        unawaited(requestSync()); // drain pending request
      }
    }
  }

  /// Merge danh sách incoming vào state hiện tại.
  /// Chỉ cập nhật khi syncVersion của booking đến cao hơn bản đang lưu.
  void _mergeItems(List<BookingModel> incoming) {
    if (incoming.isEmpty) return;
    final map = {for (final b in state) b.id: b};
    for (final b in incoming) {
      final existing = map[b.id];
      if (existing == null || b.syncVersion > existing.syncVersion) {
        map[b.id] = b;
      }
    }
    state = map.values.toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
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
    state = [created, ...state];
    return created;
  }

  /// Tạo PaymentIntent VNPay và trả về URL để mở Sandbox checkout.
  Future<PaymentIntentModel> createVnPayPayment(String bookingId) =>
      _repo.createVnPayIntent(bookingId);

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
    required double latitude,
    required double longitude,
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
