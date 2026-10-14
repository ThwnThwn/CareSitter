export '../models/shift_display_model.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/realtime/care_signalr_service.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';
import 'shift_checkin_controller.dart';
import 'live_tracking_controller.dart';
import 'shift_cache_controller.dart';
import 'shift_sync_controller.dart';
import 'shift_lifecycle_controller.dart';
import 'shift_tasks_controller.dart';
import 'shift_realtime_controller.dart';

/// Cache danh sách và các cổng thao tác công khai, thuộc một phiên đăng nhập.
class ShiftListController extends StateNotifier<List<ShiftModel>> {
  ShiftListController(Ref ref) : super([]) {
    final auth = ref.read(authStateProvider).valueOrNull;
    final identity = (auth?.userId, auth?.isAuthenticated);
    bool active() {
      if (!mounted) return false;
      final next = ref.read(authStateProvider).valueOrNull;
      return next?.isAuthenticated == true &&
          (next?.userId, next?.isAuthenticated) == identity;
    }

    final repository = ref.read(shiftRepositoryProvider);
    final cache = ShiftCacheController(
        active: active, read: () => state, write: (items) => state = items);
    _sync = ShiftSyncController(repository, cache);
    _tasks = ShiftTasksController(repository, cache);
    _lifecycle = ShiftLifecycleController(repository, cache,
        refresh: _sync.refresh,
        checkInAtLocation: (id) =>
            ref.read(shiftCheckinControllerProvider).checkIn(id),
        startTracking: (id) =>
            ref.read(liveTrackingProvider.notifier).start(id),
        reconcileTracking: (id, status) => ref
            .read(liveTrackingProvider.notifier)
            .reconcileStatus(id, status));
    _uploadSelfie = (id, image) {
      if (!active()) return Future.value('');
      return ref.read(shiftCheckinControllerProvider).uploadSelfie(id, image);
    };
    if (active()) {
      _realtime = ShiftRealtimeController(
          hub: ref.read(careSignalRProvider),
          active: active,
          refresh: _sync.refresh,
          reloadTasks: _tasks.reloadActive,
          onTask: _tasks.acceptEvent)
        ..start();
      unawaited(_sync.refresh());
    }
  }
  late final ShiftSyncController _sync;
  late final ShiftLifecycleController _lifecycle;
  late final ShiftTasksController _tasks;
  late final Future<String> Function(String, XFile) _uploadSelfie;
  ShiftRealtimeController? _realtime;
  Future<void> refresh() => _sync.refresh();
  Future<void> acceptBooking(String id) => _lifecycle.accept(id);
  Future<void> declineBooking(String id, {String? reason}) =>
      _lifecycle.decline(id, reason: reason);
  Future<void> startEnRoute(String id) => _lifecycle.enRoute(id);
  Future<void> checkIn(String id) => _lifecycle.checkIn(id);
  Future<void> checkOut(String id) => _lifecycle.checkout(id);
  Future<void> completeShift(String id) => _lifecycle.complete(id);
  Future<void> addTimelineNote(String id, String note) =>
      _lifecycle.addNote(id, note);
  Future<void> raiseSos(String id) => _lifecycle.raiseSos(id);
  Future<String> uploadCheckInSelfie(String id, XFile image) =>
      _uploadSelfie(id, image);
  Future<void> loadTasks(String id) => _tasks.load(id);
  Future<void> completeTask(String id, String taskId) =>
      _tasks.complete(id, taskId);
  Future<void> skipTask(String id, String taskId, String reason) =>
      _tasks.skip(id, taskId, reason);
  Future<void> createTask(String id, String name, {String? description}) =>
      _tasks.create(id, name, description: description);
  Future<Map<String, dynamic>> uploadTaskPhoto(
          String id, String taskId, XFile image) =>
      _tasks.uploadPhoto(id, taskId, image);
  @override
  void dispose() {
    _realtime?.dispose();
    super.dispose();
  }
}

final shiftsProvider =
    StateNotifierProvider<ShiftListController, List<ShiftModel>>((ref) {
  ref.watch(authStateProvider.select(
      (session) => (session.value?.userId, session.value?.isAuthenticated)));
  return ShiftListController(ref);
});
