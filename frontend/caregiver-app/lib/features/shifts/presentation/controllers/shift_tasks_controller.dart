import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';
import 'shift_cache_controller.dart';

class ShiftTasksController {
  ShiftTasksController(this.repository, this.cache);
  final ShiftRepository repository;
  final ShiftCacheController cache;
  Future<void> load(String id) async {
    if (!cache.active()) return;
    final tasks = await repository.loadCareTasks(id);
    cache.replaceTasks(id, tasks);
  }

  Future<void> complete(String id, String taskId) async {
    if (!cache.active()) return;
    cache.upsertTask(id, await repository.completeCareTask(id, taskId),
        insert: false);
  }

  Future<void> skip(String id, String taskId, String reason) async {
    if (!cache.active()) return;
    cache.upsertTask(id, await repository.skipCareTask(id, taskId, reason),
        insert: false);
  }

  Future<void> create(String id, String name, {String? description}) async {
    if (!cache.active()) return;
    cache.upsertTask(id,
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
      cache.upsertTask(id, task.copyWith(photoUrls: [...task.photoUrls, url]),
          insert: false);
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
      cache.upsertTask(
          id,
          CareTaskModel.fromApi(
              Map<String, dynamic>.from(event['task'] as Map)));
    } catch (_) {
      // Payload không hợp lệ được phục hồi qua load/reconnect.
    }
  }
}
