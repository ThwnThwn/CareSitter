import 'dart:async';
import '../../data/repositories/booking_repository.dart';
import '../../data/models/booking_model.dart';
import 'booking_state_controller.dart';

/// Tải/merge danh sách và cursor; không sở hữu kết nối hay thao tác ghi.
class BookingSyncController {
  BookingSyncController(this.repository, this.store,
      {required this.refreshNotifications, required this.announceAccepted});
  final BookingRepository repository;
  final BookingStateController store;
  final Future<void> Function() refreshNotifications;
  final void Function(String, String) announceAccepted;
  int _cursor = 0, _refreshGeneration = 0;
  bool _syncing = false, _pending = false;
  Future<void> refresh() async {
    if (!store.active || store.userId == null) return;
    final generation = ++_refreshGeneration;
    try {
      final result = await repository.getBookings(pageSize: 50);
      if (!store.active || generation != _refreshGeneration) return;
      store.replace(result.items);
      _cursor = result.syncCursor;
    } catch (_) {
      // Giữ cache và cursor để lần refresh tiếp theo có thể phục hồi.
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
