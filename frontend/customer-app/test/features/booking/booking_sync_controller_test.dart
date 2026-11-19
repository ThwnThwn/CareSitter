import 'package:caresitter_customer/features/booking/data/models/booking_list_response.dart';
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
    }, announceAccepted: (_, __) {}, updateLoadState: (_) {});
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
  test('refresh keeps realtime changes and their cursor when its page is older',
      () async {
    cache.replace([_booking('removed'), _booking('updated')]);
    final refresh = sync.refresh();
    final delta = sync.requestSync();
    repository.syncs.single.complete(BookingSyncResponse(
        items: [_booking('new'), _booking('updated', 2)],
        nextCursor: 3,
        serverTime: DateTime.utc(2026, 10, 12),
        hasMore: false,
        resetRequired: false));
    await delta;
    repository.loads.single.complete(BookingListResponse(
        items: [_booking('updated')],
        total: 1,
        page: 1,
        pageSize: 50,
        syncCursor: 1));
    await refresh;
    expect(items.map((booking) => (booking.id, booking.syncVersion)),
        unorderedEquals([('new', 1), ('updated', 2)]));

    final next = sync.requestSync();
    expect(repository.cursors.last, 3);
    repository.syncs.last.complete(BookingSyncResponse(
        items: [],
        nextCursor: 3,
        serverTime: DateTime.utc(2026, 10, 12),
        hasMore: false,
        resetRequired: false));
    await next;
  });
  test('a late delta resumes from the cursor of the committed snapshot',
      () async {
    final refresh = sync.refresh();
    final delta = sync.requestSync();
    repository.loads.single.complete(BookingListResponse(
        items: [_booking('current')],
        total: 1,
        page: 1,
        pageSize: 50,
        syncCursor: 4));
    await refresh;
    repository.syncs.first.complete(_delta('old'));
    await delta;
    expect(items.single.id, 'current');
    expect(repository.cursors, [0, 4]);
    repository.syncs.last.complete(BookingSyncResponse(
        items: [],
        nextCursor: 4,
        serverTime: DateTime.utc(2026, 10, 12),
        hasMore: false,
        resetRequired: false));
  });
  test('a server reset replaces old history and restarts at the lower cursor',
      () async {
    final initial = sync.requestSync();
    repository.syncs.single.complete(_delta('cached'));
    await initial;

    final reset = sync.requestSync();
    expect(repository.cursors.last, 1);
    repository.syncs.last.complete(BookingSyncResponse(
        items: [],
        nextCursor: 0,
        serverTime: DateTime.utc(2026, 10, 12),
        hasMore: false,
        resetRequired: true));
    await Future<void>.delayed(Duration.zero);
    repository.loads.single.complete(
        const BookingListResponse(items: [], total: 0, page: 1, pageSize: 50));
    await reset;
    expect(items, isEmpty);

    final next = sync.requestSync();
    expect(repository.cursors.last, 0);
    repository.syncs.last.complete(_delta('after-reset'));
    await next;
    expect(items.single.id, 'after-reset');
  });
  test('refresh loads bookings beyond the first page', () async {
    final pending = sync.refresh();
    repository.loads.first.complete(BookingListResponse(
        items: [_booking('newer')], total: 2, page: 1, pageSize: 50));
    await Future<void>.delayed(Duration.zero);
    expect(repository.pages, [1, 2]);
    repository.loads.last.complete(BookingListResponse(
        items: [_booking('older')], total: 2, page: 2, pageSize: 50));
    await pending;
    expect(items.map((booking) => booking.id), containsAll(['newer', 'older']));
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
  final pages = <int>[];
  final syncs = <Completer<BookingSyncResponse>>[];
  final cursors = <int>[];
  @override
  Future<BookingListResponse> getBookings(
      {String? status, int page = 1, int pageSize = 20}) {
    final pending = Completer<BookingListResponse>();
    pages.add(page);
    loads.add(pending);
    return pending.future;
  }

  @override
  Future<BookingSyncResponse> syncBookings(int cursor) {
    cursors.add(cursor);
    final pending = Completer<BookingSyncResponse>();
    syncs.add(pending);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
