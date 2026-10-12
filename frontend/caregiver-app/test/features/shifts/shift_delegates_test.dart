import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_mapper.dart';
import 'package:caregiver_app/features/shifts/data/repositories/shift_repository.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_cache_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_lifecycle_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_tasks_controller.dart';

void main() {
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
  @override
  Future<Map<String, dynamic>> startEnRoute(String id) => enRoute.future;
  @override
  Future<List<CareTaskModel>> loadCareTasks(String id) => tasks.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
