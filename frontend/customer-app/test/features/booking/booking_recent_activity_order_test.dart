import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/realtime/care_signalr_service.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_sync_model.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late _Repository repository;

  setUp(() async {
    repository = _Repository();
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_SignedInAuth.new),
      bookingRepositoryProvider.overrideWithValue(repository),
      bookingStoreProvider.overrideWith(_Store.new),
      careSignalRProvider.overrideWithValue(_DisconnectedHub()),
      notificationsProvider.overrideWith(_Notifications.new),
    ]);
    await container.read(authStateProvider.future);
  });

  tearDown(() => container.dispose());

  test('GET orders bookings by recent activity instead of scheduled date',
      () async {
    await container.read(bookingStoreProvider.notifier).refresh();

    expect(container.read(bookingStoreProvider).map((b) => b.id),
        ['newer', 'older']);
  });

  test('unassigned cancellation moves first and stays ordered after delta sync',
      () async {
    final store = container.read(bookingStoreProvider.notifier);
    await store.refresh();
    await store.cancel('older');

    final cancelled = container.read(bookingStoreProvider).first;
    expect(cancelled.id, 'older');
    expect(cancelled.status, 'cancelled');
    expect(cancelled.caregiverId, isNull);
    expect(cancelled.cancelledAt, DateTime.utc(2026, 10, 8, 9));
    expect(cancelled.updatedAt, cancelled.cancelledAt);

    // Bản sync cũ đến muộn không kéo ca vừa hủy xuống dưới hoặc đổi trạng thái.
    repository.delta = [repository.items.first];
    await store.requestSync();
    expect(container.read(bookingStoreProvider).first.id, 'older');
    expect(container.read(bookingStoreProvider).first.status, 'cancelled');

    // Một ca khác được cập nhật sau phải lên đầu khi nhận delta mới.
    repository.delta = [
      repository.items.last.copyWith(
        updatedAt: DateTime.utc(2026, 10, 9),
        syncVersion: 2,
      ),
    ];
    await store.requestSync();
    expect(container.read(bookingStoreProvider).map((b) => b.id),
        ['newer', 'older']);
  });
}

class _Store extends BookingStore {
  @override
  List<BookingModel> build() => const [];
}

class _SignedInAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'customer', isAuthenticated: true);
}

class _DisconnectedHub implements CareSignalRService {
  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications extends NotificationsNotifier {
  @override
  Future<List<AppNotification>> build() async => const [];

  @override
  Future<void> refresh() async {}
}

class _UnusedClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends BookingRepository {
  _Repository() : super(_UnusedClient());

  final items = [
    BookingModel.fromJson({
      'id': 'older',
      'status': 'pending_payment',
      'scheduledStart': '2026-12-01T01:00:00Z',
      'scheduledEnd': '2026-12-01T05:00:00Z',
      'createdAt': '2026-10-01T00:00:00Z',
      'updatedAt': '2026-10-01T00:00:00Z',
      'syncVersion': 1,
    }),
    BookingModel.fromJson({
      'id': 'newer',
      'status': 'cancelled',
      'scheduledStart': '2026-11-01T01:00:00Z',
      'scheduledEnd': '2026-11-01T05:00:00Z',
      'createdAt': '2026-10-02T00:00:00Z',
      'updatedAt': '2026-10-07T00:00:00Z',
      'cancelledAt': '2026-10-07T00:00:00Z',
      'syncVersion': 1,
    }),
  ];
  List<BookingModel> delta = [];

  @override
  Future<BookingListResponse> getBookings(
          {String? status, int page = 1, int pageSize = 20}) async =>
      BookingListResponse(
          items: items, total: items.length, page: page, pageSize: pageSize);

  @override
  Future<BookingModel> cancelBooking(String bookingId,
          {String? reason}) async =>
      items.firstWhere((b) => b.id == bookingId).copyWith(
            status: 'cancelled',
            cancelledAt: DateTime.utc(2026, 10, 8, 9),
            updatedAt: DateTime.utc(2026, 10, 8, 9),
            syncVersion: 2,
          );

  @override
  Future<BookingSyncResponse> syncBookings(int cursor) async =>
      BookingSyncResponse(
          items: delta,
          nextCursor: cursor + 1,
          serverTime: DateTime.utc(2026, 10, 9),
          hasMore: false,
          resetRequired: false);
}
