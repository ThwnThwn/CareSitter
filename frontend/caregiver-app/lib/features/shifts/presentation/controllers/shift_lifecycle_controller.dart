import 'package:caregiver_app/core/error/app_exception.dart';
import '../../data/repositories/shift_repository.dart';
import 'shift_cache_controller.dart';

class ShiftLifecycleController {
  ShiftLifecycleController(this.repository, this.cache,
      {required this.refresh,
      required this.checkInAtLocation,
      required this.startTracking,
      required this.reconcileTracking});
  final ShiftRepository repository;
  final ShiftCacheController cache;
  final Future<void> Function() refresh;
  final Future<DateTime?> Function(String) checkInAtLocation;
  final Future<void> Function(String) startTracking;
  final void Function(String, String) reconcileTracking;
  final Set<String> _pending = {};
  Future<void> _run(String id, Future<void> Function() action) async {
    if (!cache.active()) return;
    if (!_pending.add(id)) {
      throw const AppApiException(message: 'Ca đang được xử lý. Vui lòng chờ.');
    }
    try {
      await action();
    } finally {
      _pending.remove(id);
    }
  }

  Future<void> accept(String id) => _run(id, () async {
        try {
          await repository.acceptBooking(id);
        } catch (_) {
          await refresh();
          rethrow;
        }
        await refresh();
      });
  Future<void> decline(String id, {String? reason}) => _run(id, () async {
        try {
          await repository.declineBooking(id, reason: reason);
        } catch (_) {
          await refresh();
          rethrow;
        }
        cache.remove(id);
      });
  Future<void> enRoute(String id) => _run(id, () async {
        await repository.startEnRoute(id);
        if (!cache.active()) return;
        cache.patch(id, (item) => item.copyWith(status: 'caregiver_en_route'));
        await startTracking(id);
      });
  Future<void> checkIn(String id) => _run(id, () async {
        final started = await checkInAtLocation(id);
        if (!cache.active()) return;
        reconcileTracking(id, 'in_progress');
        cache.patch(
            id,
            (item) => item.copyWith(
                status: 'in_progress', actualStart: started ?? DateTime.now()));
      });
  Future<void> checkout(String id) => _run(id, () async {
        await repository.requestCheckout(id);
        cache.patch(
            id,
            (item) => item.copyWith(
                status: 'checkout_pending_review',
                checkoutRequestedAt: DateTime.now()));
      });
  Future<void> complete(String id) => _run(id, () async {
        try {
          await repository.completeBooking(id);
        } catch (_) {
          return;
        }
        cache.patch(
            id,
            (item) => item.copyWith(
                status: 'completed', completedAt: DateTime.now()));
      });
  Future<void> addNote(String id, String note) async {
    if (!cache.active() || note.trim().isEmpty) return;
    await repository.addTimelineNote(id, note.trim());
  }

  Future<void> raiseSos(String id) async {
    if (!cache.active()) return;
    await repository.raiseSos(id);
    cache.patch(id, (item) => item.copyWith(status: 'crisis'));
  }
}
