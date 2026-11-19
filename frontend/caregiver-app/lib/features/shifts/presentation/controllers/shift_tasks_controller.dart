import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';
import 'shift_cache_controller.dart';

class ShiftTasksController {
  ShiftTasksController(this.repository, this.cache);
  final ShiftRepository repository;
  final ShiftCacheController cache;
  final _reads = <String, int>{};
  final _changes = <String, Map<String, int>>{};
  int _sequence = 0;

  void _update(String id, CareTaskModel task) {
    if (!cache.active()) return;
    (_changes[id] ??= {})[task.id] = ++_sequence;
    cache.upsertTask(id, task);
  }

  Future<void> load(String id) async {
    if (!cache.active()) return;
    final revision = _reads[id] = ++_sequence;
    final tasks = await repository.loadCareTasks(id);
    if (!cache.active() || _reads[id] != revision) return;
    final updates = _changes[id];
    final newer = {
      for (final task in cache.find(id)?.tasks ?? const <CareTaskModel>[])
        if ((updates?[task.id] ?? 0) > revision) task.id: task,
    };
    final merged = [
      for (final task in tasks) newer.remove(task.id) ?? task,
      ...newer.values,
    ];
    merged.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    cache.replaceTasks(id, merged);
  }

  Future<void> complete(String id, String taskId) async {
    if (!cache.active()) return;
    _update(id, await repository.completeCareTask(id, taskId));
  }

  Future<void> skip(String id, String taskId, String reason) async {
    if (!cache.active()) return;
    _update(id, await repository.skipCareTask(id, taskId, reason));
  }

  Future<void> create(String id, String name, {String? description}) async {
    if (!cache.active()) return;
    _update(id,
        await repository.createCareTask(id, name, description: description));
  }

  Future<Map<String, dynamic>> uploadPhoto(
      String id, String taskId, XFile image) async {
    if (!cache.active()) return const {};
    final photo = await repository.attachTaskPhoto(id, taskId, image);
    if (!cache.active()) return photo.toJson();
    final task = cache.items
        .where((item) => item.id == id)
        .firstOrNull
        ?.tasks
        .where((task) => task.id == taskId)
        .firstOrNull;
    final url = photo.url;
    if (task != null && url != null && url.isNotEmpty) {
      _update(id, task.copyWith(photoUrls: {...task.photoUrls, url}.toList()));
    }
    return photo.toJson();
  }

  void reloadActive() {
    for (final item
        in cache.items.where((item) => item.status == 'in_progress')) {
      unawaited(load(item.id).catchError((_) {}));
    }
  }

  void acceptEvent(Map<String, dynamic> event) {
    if (!cache.active()) return;
    try {
      final id = event['bookingId']?.toString();
      if (id == null || event['task'] is! Map) return;
      final task = CareTaskModel.fromApi(
          Map<String, dynamic>.from(event['task'] as Map));
      if (task.id.isNotEmpty) _update(id, task);
    } catch (_) {
      // Payload không hợp lệ được phục hồi qua load/reconnect.
    }
  }
}
