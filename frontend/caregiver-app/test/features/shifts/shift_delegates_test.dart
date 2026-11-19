import 'dart:async';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_mapper.dart';
import 'package:caregiver_app/features/shifts/data/repositories/shift_repository.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_cache_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_lifecycle_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_tasks_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_sync_controller.dart';

void main() {
  test('a list refresh cannot resurrect a declined invitation', () async {
    final offer = mapShiftFromApi({'id': 'offer', 'status': 'open'});
    var items = [offer];
    final cache = ShiftCacheController(
        active: () => true, read: () => items, write: (next) => items = next);
    final repository = _Repository();
    final sync = ShiftSyncController(repository, cache);
    final lifecycle = ShiftLifecycleController(repository, cache,
        refresh: sync.refresh,
        checkInAtLocation: (_) async => null,
        startTracking: (_) async {},
        reconcileTracking: (_, __) {});
    final stale = sync.refresh();
    await lifecycle.decline(offer.id);
    repository.list.complete([offer]);
    await stale;
    expect(items, isEmpty);
  });

  test('a stale task GET preserves newer changes and loads untouched tasks',
      () async {
    const changed = CareTaskModel(id: 't', title: 'Task', sortOrder: 1);
    const untouched = CareTaskModel(id: 'u', title: 'Task', sortOrder: 2);
    var items = [
      mapShiftFromApi({'id': 'shift', 'status': 'in_progress'})
          .copyWith(tasks: [changed])
    ];
    final cache = ShiftCacheController(
        active: () => true, read: () => items, write: (next) => items = next);
    final repository = _Repository();
    final controller = ShiftTasksController(repository, cache);
    final stale = controller.load('shift');
    await controller.complete('shift', 't');
    controller.acceptEvent({
      'bookingId': 'shift',
      'task': {'id': 'new', 'name': 'New task', 'sortOrder': 3}
    });
    repository.tasks.complete([changed, untouched]);
    await stale;
    expect(items.single.tasks.map((task) => task.id), ['t', 'u', 'new']);
    expect(items.single.tasks.first.isCompleted, isTrue);
  });

  test('checkout with a lost response reconciles the saved state by ID',
      () async {
    var items = [
      mapShiftFromApi({'id': 'shift', 'status': 'in_progress'})
    ];
    final cache = ShiftCacheController(
        active: () => true, read: () => items, write: (next) => items = next);
    final repository = _Repository();
    final controller = ShiftLifecycleController(repository, cache,
        refresh: () async {},
        checkInAtLocation: (_) async => null,
        startTracking: (_) async {},
        reconcileTracking: (_, __) {});
    await controller.checkout('shift', 'Đã hỗ trợ ăn tối');
    expect(repository.checkoutNotes, ['Đã hỗ trợ ăn tối']);
    expect(items.single.status, 'checkout_pending_review');
  });
  test('a late en-route response cannot start GPS after the session closes',
      () async {
    var active = true, tracking = 0;
    var items = [
      mapShiftFromApi({'id': 'shift', 'status': 'caregiver_accepted'})
    ];
    final cache = ShiftCacheController(
        active: () => active, read: () => items, write: (next) => items = next);
    final repository = _Repository();
    final actions = ShiftLifecycleController(repository, cache,
        refresh: () async {},
        checkInAtLocation: (_) async => null,
        startTracking: (_) async {
          tracking++;
        },
        reconcileTracking: (_, __) {});
    final pending = actions.enRoute('shift');
    active = false;
    repository.enRoute.complete({});
    await pending;
    expect(tracking, 0);
    expect(items.single.status, 'confirmed');
  });
  test('a late task response cannot mutate a cache from another session',
      () async {
    var active = true;
    var items = [
      mapShiftFromApi({'id': 'shift', 'status': 'in_progress'})
    ];
    final cache = ShiftCacheController(
        active: () => active, read: () => items, write: (next) => items = next);
    final repository = _Repository();
    final pending = ShiftTasksController(repository, cache).load('shift');
    active = false;
    repository.tasks.complete([const CareTaskModel(id: 'task', title: 'Task')]);
    await pending;
    expect(items.single.tasks, isEmpty);
  });
  test('repeated task events replace the same ID without adding duplicates',
      () {
    var items = [
      mapShiftFromApi({'id': 'shift', 'status': 'in_progress'})
    ];
    final cache = ShiftCacheController(
        active: () => true, read: () => items, write: (next) => items = next);
    cache.upsertTask('shift', const CareTaskModel(id: 'task', title: 'Task'));
    cache.upsertTask(
        'shift',
        const CareTaskModel(
            id: 'task', title: 'Task', status: 'COMPLETED', isCompleted: true));
    expect(items.single.tasks, hasLength(1));
    expect(items.single.tasks.single.isCompleted, isTrue);
  });
}

class _Repository implements ShiftRepository {
  final enRoute = Completer<Map<String, dynamic>>();
  final tasks = Completer<List<CareTaskModel>>();
  final list = Completer<List<ShiftModel>>();
  final checkoutNotes = <String>[];
  @override
  Future<List<ShiftModel>> loadAssignedAndOffers() => list.future;
  @override
  Future<void> declineBooking(String id, {String? reason}) async {}
  @override
  Future<CareTaskModel> completeCareTask(String id, String taskId) async =>
      CareTaskModel(
          id: taskId,
          title: 'Task',
          sortOrder: 1,
          status: 'COMPLETED',
          isCompleted: true);
  @override
  Future<ShiftModel> requestCheckout(String id, String note) async {
    checkoutNotes.add(note);
    throw const AppApiException(message: 'Mất phản hồi');
  }

  @override
  Future<ShiftModel> loadShift(String id, {ApiCancellation? token}) async =>
      mapShiftFromApi({'id': id, 'status': 'checkout_pending_review'});
  @override
  Future<String> loadCheckoutNote(String id, {ApiCancellation? token}) async =>
      checkoutNotes.single;
  @override
  Future<Map<String, dynamic>> startEnRoute(String id) => enRoute.future;
  @override
  Future<List<CareTaskModel>> loadCareTasks(String id,
          {ApiCancellation? token}) =>
      tasks.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
