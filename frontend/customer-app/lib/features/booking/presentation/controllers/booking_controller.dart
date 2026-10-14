import 'package:caresitter_customer/features/booking/data/models/booking_list_response.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/notifications/in_app_notification_events.dart';
import 'package:caresitter_customer/core/realtime/care_signalr_service.dart';
import '../../../home/presentation/controllers/notifications_controller.dart';
import '../../../review/data/repositories/review_repository.dart';
import '../../data/repositories/booking_repository.dart';
import '../../data/models/booking_model.dart';
import 'booking_action_controller.dart';
import 'booking_payment_controller.dart';
import 'booking_review_controller.dart';
import 'booking_state_controller.dart';
import 'booking_sync_controller.dart';
import 'booking_realtime_controller.dart';
import 'booking_tasks_controller.dart';
export 'booking_created_exception.dart';
export '../models/booking_display_model.dart';
export 'booking_outcome_unknown.dart';
export '../../data/models/booking_model.dart';
export '../../data/repositories/booking_repository.dart' show BookingDraft;

final bookingStoreProvider =
    NotifierProvider<BookingStore, List<BookingModel>>(BookingStore.new);

/// Cache phiên đăng nhập và façade tương thích cho các provider công khai.
class BookingStore extends Notifier<List<BookingModel>> {
  BookingRepository get _repo => ref.read(bookingRepositoryProvider);
  BookingStateController? _cache;
  BookingSyncController? _sync;
  BookingRealtimeController? _realtime;
  BookingPaymentController? _payments;
  BookingStateController get _store {
    if (_cache != null) return _cache!;
    final identity = _identity;
    final cache = BookingStateController(
        userId: identity.$1,
        current: () => identity.$2 && _identity == identity,
        read: () => state,
        write: (items) => state = items);
    _cache = cache;
    ref.onDispose(cache.close);
    return cache;
  }

  (String?, bool) get _identity {
    final auth = ref.read(authStateProvider).valueOrNull;
    return (auth?.userId, auth?.isAuthenticated ?? false);
  }

  BookingActionController get _actions => BookingActionController(_repo, _store);
  BookingTasksController get _tasks => BookingTasksController(_repo, _store);
  BookingReviewController get _reviews =>
      BookingReviewController(ref.read(reviewRepositoryProvider), _store);
  BookingPaymentController get _payment =>
      _payments ??= BookingPaymentController(_repo);
  BookingSyncController get _synchronizer =>
      _sync ??= BookingSyncController(_repo, _store,
          refreshNotifications: _refreshNotifications,
          announceAccepted: _announceAccepted);
  BookingRealtimeController get _events {
    if (_realtime != null) return _realtime!;
    final cache = _store;
    final tasks = _tasks;
    final sync = _synchronizer;
    final events = BookingRealtimeController(
        hub: () => ref.read(careSignalRProvider),
        active: () => cache.active && _identity.$2,
        sync: sync.requestSync,
        refreshNotifications: _refreshNotifications,
        reloadTasks: tasks.reloadActive,
        onTask: tasks.acceptEvent,
        announceAccepted: _announceAccepted);
    _realtime = events;
    ref.onDispose(events.dispose);
    return events;
  }

  @override
  List<BookingModel> build() {
    ref.watch(authStateProvider.select(
        (auth) => (auth.valueOrNull?.userId, auth.valueOrNull?.isAuthenticated)));
    _cache?.close();
    _realtime?.dispose();
    _cache = null;
    _sync = null;
    _realtime = null;
    _payments = null;
    if (_identity.$2) {
      final cache = _store;
      final sync = _synchronizer;
      final events = _events;
      Future.microtask(() async {
        if (!cache.active) return;
        await sync.refresh();
        if (cache.active) await events.connect();
      });
    }
    return const [];
  }

  Future<void> _refreshNotifications() =>
      ref.read(notificationsProvider.notifier).refresh();
  void _announceAccepted(String bookingId, String status) {
    ref.read(inAppNotificationEventsProvider).publish(InAppNotificationEvent(
        title: 'Caregiver đã nhận ca',
        body: 'Caregiver đã xác nhận lịch chăm sóc của bạn.',
        data: {
          'type': 'BOOKING',
          'bookingId': bookingId,
          'status': status,
          'deepLink': '/bookings/$bookingId'
        },
        deduplicationKey: 'booking:$bookingId:${status.toLowerCase()}'));
  }

  Future<void> refresh() => _synchronizer.refresh();
  Future<void> requestSync() async {
    final sync = _synchronizer;
    unawaited(_events.connect());
    await sync.requestSync();
  }

  Future<BookingModel> getBooking(String id) => _repo.getBooking(id);
  Future<GpsTrackModel?> getLatestGps(String id) => _repo.getLatestGps(id);
  Future<BookingListResponse> getBookings({int page = 1, int pageSize = 50}) =>
      _repo.getBookings(page: page, pageSize: pageSize);
  Future<List<PaymentProviderModel>> getPaymentProviders() => _payment.providers();
  Future<PaymentIntentModel> createPaymentIntent(String id, String provider) =>
      _payment.create(id, provider);
  Future<PaymentIntentModel> getPaymentIntent(String id) => _payment.get(id);
  Future<PaymentIntentModel> createVnPayPayment(String id) =>
      createPaymentIntent(id, 'VNPAY');
  Future<BookingModel> createBooking(BookingDraft draft) => _actions.create(draft);
  Future<void> caregiverEnRoute(String id) => _actions.enRoute(id);
  Future<void> caregiverCheckIn(String id,
          {required double latitude, required double longitude}) =>
      _actions.checkIn(id, latitude: latitude, longitude: longitude);
  Future<void> caregiverRequestCheckout(String id) => _actions.checkout(id);
  Future<void> confirmCompleted(String id) => _actions.complete(id);
  Future<void> cancel(String id, {String? reason}) =>
      _actions.cancel(id, reason: reason);
  Future<void> openDispute(String id, String reason, {String? description}) =>
      _reviews.dispute(id, reason, description: description);
  Future<void> markReviewed(String id,
          {String? caregiverId,
          int? rating,
          String? comment,
          String? experienceTags}) =>
      _reviews.review(id,
          caregiverId: caregiverId,
          rating: rating,
          comment: comment,
          experienceTags: experienceTags);
  Future<List<CareTaskModel>> loadTasks(String id) => _tasks.load(id);
}
