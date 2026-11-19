import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';
import 'shift_cache_controller.dart';

class ShiftSyncController {
  ShiftSyncController(this.repository, this.cache);
  final ShiftRepository repository;
  final ShiftCacheController cache;
  int _generation = 0;

  Future<ShiftModel> loadDetail(String id, ApiCancellation token) async {
    if (!cache.active()) {
      throw const AppApiException(message: 'Phiên tải ca đã kết thúc.');
    }
    final revision = cache.revision;
    final item = await repository.loadShift(id, token: token);
    if (!cache.active() || token.isCancelled) {
      throw const AppApiException(message: 'Phiên tải ca đã kết thúc.');
    }
    final cached = cache.find(id);
    if (cached != null) return cached;
    if (revision != cache.revision) {
      throw const AppApiException(
          message: 'Danh sách ca vừa thay đổi. Vui lòng thử lại.');
    }
    if (item.caregiverId != null &&
        item.status != 'completed' &&
        item.status != 'cancelled') {
      cache.retain(item);
    }
    return item;
  }

  Future<void> refresh() async {
    if (!cache.active()) return;
    final generation = ++_generation;
    final revision = cache.revision;
    try {
      final loaded = await repository.loadAssignedAndOffers();
      if (!cache.active() ||
          generation != _generation ||
          revision != cache.revision) {
        return;
      }
      final tasks = {
        for (final item in cache.items)
          if (item.tasks.isNotEmpty) item.id: item.tasks
      };
      cache.replacePage(
          [for (final item in loaded) item.copyWith(tasks: tasks[item.id])]);
    } catch (_) {
      // Giữ danh sách cũ; polling hoặc tín hiệu realtime tiếp theo tải lại.
    }
  }
}
