import 'dart:async';
import '../../data/repositories/booking_repository.dart';
import '../../data/models/booking_model.dart';
import 'booking_list_load_controller.dart';
import 'booking_state_controller.dart';

/// Tải/merge danh sách và cursor; không sở hữu kết nối hay thao tác ghi.
class BookingSyncController {
  BookingSyncController(this.repository, this.store,
      {required this.refreshNotifications,
      required this.announceAccepted,
      required this.updateLoadState});
  final BookingRepository repository;
  final BookingStateController store;
  final Future<void> Function() refreshNotifications;
  final void Function(String, String) announceAccepted;
  final void Function(BookingListLoadState) updateLoadState;
  int _cursor = 0, _refreshGeneration = 0;
  bool _syncing = false, _pending = false;

  bool _current(int generation) =>
      store.active && generation == _refreshGeneration;

  Future<void> refresh() async {
    if (!store.active || store.userId == null) return;
    final generation = ++_refreshGeneration;
    final before = {for (final item in store.items) item.id: item};
    final cursorAtStart = _cursor;
    updateLoadState(BookingListLoadState.loading);
    try {
      const pageSize = 50;
      final first = await repository.getBookings(pageSize: pageSize);
      if (!_current(generation)) return;
      final bookings = <BookingModel>[...first.items];
      var page = 2;
      while (bookings.length < first.total && first.items.isNotEmpty) {
        final next =
            await repository.getBookings(page: page, pageSize: pageSize);
        if (!_current(generation)) return;
        if (next.items.isEmpty) break;
        bookings.addAll(next.items);
        page++;
      }
      // A delta that committed during this read owns its newer cursor.
      // Otherwise use the server cursor, including after a server reset.
      if (_cursor == cursorAtStart || first.syncCursor > _cursor) {
        _cursor = first.syncCursor;
      }
      // A delta still in flight must restart from the committed snapshot cursor.
      final committedGeneration = ++_refreshGeneration;
      store.replaceSnapshot(bookings, before);
      if (_current(committedGeneration)) {
        updateLoadState(BookingListLoadState.ready);
      }
    } catch (_) {
      if (_current(generation)) updateLoadState(BookingListLoadState.failed);
    }
  }

  Future<void> requestSync() async {
    if (!store.active || store.userId == null) return;
    if (_syncing) {
      _pending = true;
      return;
    }
    _syncing = true;
    try {
      var hasMore = true, changed = false;
      final accepted = <BookingModel>[];
      while (hasMore && store.active) {
        final generation = _refreshGeneration;
        final result = await repository.syncBookings(_cursor);
        if (!store.active) return;
        if (generation != _refreshGeneration) {
          _pending = true;
          return;
        }
        if (result.resetRequired) {
          await refresh();
          return;
        }
        final incoming = result.items.cast<BookingModel>();
        changed = changed || incoming.isNotEmpty;
        accepted.addAll(store
            .merge(incoming)
            .where((b) => b.status == 'caregiver_accepted'));
        _cursor = result.nextCursor;
        hasMore = result.hasMore;
      }
      if (changed && store.active) await refreshNotifications();
      if (!store.active) return;
      for (final item in accepted) {
        announceAccepted(item.id, item.status);
      }
    } catch (_) {
      // Không tiến cursor khi request lỗi; tick/reconnect sau sẽ đối soát.
    } finally {
      _syncing = false;
      if (_pending && store.active) {
        _pending = false;
        unawaited(requestSync());
      }
    }
  }
}
