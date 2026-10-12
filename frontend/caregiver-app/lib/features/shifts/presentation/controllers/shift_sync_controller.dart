import '../../data/repositories/shift_repository.dart';
import 'shift_cache_controller.dart';

class ShiftSyncController {
  ShiftSyncController(this.repository, this.cache);
  final ShiftRepository repository;
  final ShiftCacheController cache;
  int _generation = 0;
  Future<void> refresh() async {
    if (!cache.active()) return;
    final generation = ++_generation;
    try {
      final loaded = await repository.loadAssignedAndOffers();
      if (!cache.active() || generation != _generation) return;
      final tasks = {
        for (final item in cache.items)
          if (item.tasks.isNotEmpty) item.id: item.tasks
      };
      cache.replace(
          [for (final item in loaded) item.copyWith(tasks: tasks[item.id])]);
    } catch (_) {
      // Giữ danh sách cũ; polling hoặc tín hiệu realtime tiếp theo tải lại.
    }
  }
}
