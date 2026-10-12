import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_sync_model.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_state_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_sync_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_action_controller.dart';

void main() {
  late _Repository repository;
  late BookingStateController cache;
  late BookingSyncController sync;
  var items = <BookingModel>[];
  var notifications = 0;
  setUp(() {
    items = [];
    notifications = 0;
    repository = _Repository();
    cache = BookingStateController(
        userId: 'owner',
        current: () => true,
        read: () => items,
        write: (next) => items = next);
    sync = BookingSyncController(repository, cache,
        refreshNotifications: () async {
      notifications++;
    }, announceAccepted: (_, __) {});
  });
  test('a late full refresh cannot overwrite a newer refresh', () async {
    final old = sync.refresh();
    final latest = sync.refresh();
    repository.loads.last.complete(_list('latest'));
    await latest;
    repository.loads.first.complete(_list('old'));
    await old;
    expect(items.single.id, 'latest');
  });
  test('closing the session ignores pending refresh and stops future requests',
      () async {
    final pending = sync.refresh();
    cache.close();
    repository.loads.single.complete(_list('old-account'));
    await pending;
    await sync.refresh();
    await sync.requestSync();
    expect(items, isEmpty);
    expect(repository.loads, hasLength(1));
    expect(repository.syncs, isEmpty);
  });
  test('delta arriving after session close cannot patch cache or notify',
      () async {
    final pending = sync.requestSync();
    cache.close();
    repository.syncs.single.complete(_delta('old-account'));
    await pending;
    expect(items, isEmpty);
    expect(notifications, 0);
  });
  test('an older delta cannot undo a more recent mutation', () {
    final current = _booking('same', 2);
    cache.replace([current]);
    expect(cache.merge([_booking('same', 1)]), isEmpty);
    expect(items.single.syncVersion, 2);
  });
  test('a late cancellation cannot report success after the session closes',
      () async {
    final pending =
        BookingActionController(repository, cache).cancel('booking');
    final expectation = expectLater(pending, throwsStateError);
    cache.close();
    repository.canceled
        .complete(_booking('booking').copyWith(status: 'cancelled'));
    await expectation;
    expect(items, isEmpty);
  });
  test('a closed session cannot send a cancellation request', () async {
    cache.close();
    await expectLater(
        BookingActionController(repository, cache).cancel('booking'),
        throwsStateError);
    expect(repository.cancelCalls, 0);
  });
}

BookingModel _booking(String id, [int version = 1]) => BookingModel.fromJson({
      'id': id,
      'status': 'confirmed',
      'syncVersion': version,
      'scheduledStart': '2026-10-15T07:00:00Z',
      'scheduledEnd': '2026-10-15T09:00:00Z',
    });
BookingListResponse _list(String id) =>
    BookingListResponse(items: [_booking(id)], total: 1, page: 1, pageSize: 50);
BookingSyncResponse _delta(String id) => BookingSyncResponse(
    items: [_booking(id)],
    nextCursor: 1,
    serverTime: DateTime.utc(2026, 10, 12),
    hasMore: false,
    resetRequired: false);

class _Repository implements BookingRepository {
  final canceled = Completer<BookingModel>();
  int cancelCalls = 0;
  @override
  Future<BookingModel> cancelBooking(String id, {String? reason}) {
    cancelCalls++;
    return canceled.future;
  }

  final loads = <Completer<BookingListResponse>>[];
  final syncs = <Completer<BookingSyncResponse>>[];
  @override
  Future<BookingListResponse> getBookings(
      {String? status, int page = 1, int pageSize = 20}) {
    final pending = Completer<BookingListResponse>();
    loads.add(pending);
    return pending.future;
  }

  @override
  Future<BookingSyncResponse> syncBookings(int cursor) {
    final pending = Completer<BookingSyncResponse>();
    syncs.add(pending);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
