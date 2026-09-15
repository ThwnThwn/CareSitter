import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/notifications/in_app_notification_events.dart';
import '../../../core/realtime/care_signalr_service.dart';
import '../../home/application/notifications_store.dart';
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
  final Set<String> _announcedRealtimeEvents = {};
  bool _realtimeSubscribed = false;

  @override
  List<BookingModel> build() {
    _cancelRealtimeSubscriptions();
    _lastCursor = 0;
    _isSyncing = false;
    _syncPending = false;
    _announcedRealtimeEvents.clear();

    ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth &&
          prev?.value?.isAuthenticated == true &&
          prev?.value?.userId == next.value?.userId) {
        return;
      }
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
      signalR.customerSyncStream.listen((_) {
        unawaited(requestSync());
        // BookingListSync cũng là fallback khi BookingStatusChanged bị miss
        // trong lúc hub reconnect; inbox vẫn phản ánh notification đã lưu ở BE.
        unawaited(ref.read(notificationsProvider.notifier).refresh());
      }),
    );
    _subscriptions.add(
      signalR.statusStream.listen((change) {
        unawaited(_handleBookingStatusChanged(change));
      }),
    );
    _subscriptions.add(
      signalR.onReconnected.listen((_) {
        requestSync();
        _reloadActiveBookingTasks();
      }),
    );
    _subscriptions.add(
      signalR.onTaskUpdated.listen((data) => _handleTaskUpdated(data)),
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
    // withAutomaticReconnect chỉ áp dụng sau một kết nối thành công. Nếu lần
    // connect đầu tiên thất bại, polling sync sẽ thử mở lại hub ở tick tiếp theo.
    if (!_realtimeSubscribed || !ref.read(careSignalRProvider).isConnected) {
      unawaited(_startRealtime());
    }
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
      var receivedBookingChanges = false;
      final acceptedBookings = <BookingModel>[];
      while (hasMore) {
        final result = await _repo.syncBookings(_lastCursor);
        if (result.resetRequired) {
          await _loadFromApi(); // full refresh, reset cursor
          return;
        }
        final items = result.items.cast<BookingModel>();
        if (items.isNotEmpty) receivedBookingChanges = true;
        acceptedBookings.addAll(
          _mergeItems(items).where(
            (booking) => booking.status == 'caregiver_accepted',
          ),
        );
        _lastCursor = result.nextCursor;
        hasMore = result.hasMore;
      }

      // Notification đã được persist trong BE cùng luồng nhận ca. Refresh sau
      // delta giúp bell/inbox vẫn cập nhật kể cả khi SignalR status event bị miss.
      if (receivedBookingChanges) {
        await ref.read(notificationsProvider.notifier).refresh();
      }
      for (final booking in acceptedBookings) {
        _publishCaregiverAcceptedNotification(
          booking.id,
          booking.status,
        );
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
  List<BookingModel> _mergeItems(List<BookingModel> incoming) {
    if (incoming.isEmpty) return const [];
    final map = {for (final b in state) b.id: b};
    final changed = <BookingModel>[];
    for (final b in incoming) {
      final existing = map[b.id];
      if (existing == null || b.syncVersion > existing.syncVersion) {
        map[b.id] = b;
        changed.add(b);
      }
    }
    state = map.values.toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
    return changed;
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
      rethrow;
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

  /// Tải danh sách tasks từ backend cho booking cụ thể.
  Future<List<CareTaskModel>> loadTasks(String bookingId) async {
    try {
      final tasks = await _repo.getTasks(bookingId);
      _updateBookingTasks(bookingId, tasks);
      return tasks;
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] loadTasks error for $bookingId: $e');
      return [];
    }
  }

  void _reloadActiveBookingTasks() {
    for (final b in state) {
      if (b.status == 'in_progress' ||
          b.status == 'caregiver_en_route' ||
          b.status == 'checkout_pending_review') {
        unawaited(loadTasks(b.id));
      }
    }
  }

  void _handleTaskUpdated(Map<String, dynamic> data) {
    try {
      final bookingId = data['bookingId']?.toString();
      final rawTask = data['task'];
      if (bookingId == null || rawTask == null) return;
      final taskMap = Map<String, dynamic>.from(rawTask as Map);
      final task = CareTaskModel.fromApi(taskMap);
      _upsertTask(bookingId, task);
    } catch (e) {
      // ignore: avoid_print
      print('[BookingStore] _handleTaskUpdated error: $e');
    }
  }

  Future<void> _handleBookingStatusChanged(BookingStatusChange change) async {
    if (change.bookingId.isEmpty ||
        change.newStatus.toLowerCase() != 'caregiver_accepted') {
      return;
    }

    // A tracking screen may be joined to both booking and customer groups.
    // Keep one foreground notification for the same server event.
    final key =
        '${change.bookingId}:${change.newStatus}:${change.changedAt.toUtc().microsecondsSinceEpoch}';
    if (!_announcedRealtimeEvents.add(key)) return;
    if (_announcedRealtimeEvents.length > 128) {
      _announcedRealtimeEvents.clear();
      _announcedRealtimeEvents.add(key);
    }

    await requestSync();
    await ref.read(notificationsProvider.notifier).refresh();
    _publishCaregiverAcceptedNotification(change.bookingId, change.newStatus);
  }

  void _publishCaregiverAcceptedNotification(String bookingId, String status) {
    ref.read(inAppNotificationEventsProvider).publish(
          InAppNotificationEvent(
            title: 'Caregiver đã nhận ca',
            body: 'Caregiver đã xác nhận lịch chăm sóc của bạn.',
            data: {
              'type': 'BOOKING',
              'bookingId': bookingId,
              'status': status,
              'deepLink': '/bookings/$bookingId',
            },
            deduplicationKey: 'booking:$bookingId:${status.toLowerCase()}',
          ),
        );
  }

  void _updateBookingTasks(String bookingId, List<CareTaskModel> tasks) {
    state = [
      for (final b in state)
        if (b.id == bookingId)
          b.copyWith(
            tasks: tasks,
            needsReview: tasks.any((t) => t.isRequired && t.isSkipped),
          )
        else
          b,
    ];
  }

  void _upsertTask(String bookingId, CareTaskModel task) {
    state = [
      for (final b in state)
        if (b.id == bookingId)
          () {
            final existing = b.tasks;
            final idx = existing.indexWhere((t) => t.id == task.id);
            List<CareTaskModel> updated;
            if (idx >= 0) {
              updated = List<CareTaskModel>.from(existing);
              updated[idx] = task;
            } else {
              updated = [...existing, task]
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            }
            return b.copyWith(
              tasks: updated,
              needsReview: updated.any((t) => t.isRequired && t.isSkipped),
            );
          }()
        else
          b,
    ];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
