import 'dart:async';
import '../../data/repositories/booking_repository.dart';
import '../../data/models/booking_model.dart';
import 'booking_state_controller.dart';

class BookingTasksController {
  BookingTasksController(this.repository, this.store);
  final BookingRepository repository;
  final BookingStateController store;
  Future<List<CareTaskModel>> load(String id) async {
    if (!store.active) return const [];
    try {
      final tasks = await repository.getTasks(id);
      if (!store.active) return const [];
      store.replace([
        for (final item in store.items)
          if (item.id == id)
            item.copyWith(
                tasks: tasks,
                needsReview:
                    tasks.any((task) => task.isRequired && task.isSkipped))
          else
            item
      ]);
      return tasks;
    } catch (_) {
      return const [];
    }
  }

  void reloadActive() {
    for (final item in store.items) {
      if (const {'in_progress', 'caregiver_en_route', 'checkout_pending_review'}
          .contains(item.status)) {
        unawaited(load(item.id));
      }
    }
  }

  void acceptEvent(Map<String, dynamic> data) {
    if (!store.active) return;
    try {
      final id = data['bookingId']?.toString();
      if (id == null || data['task'] is! Map) return;
      final task =
          CareTaskModel.fromApi(Map<String, dynamic>.from(data['task'] as Map));
      store.replace([
        for (final item in store.items)
          if (item.id == id) _upsert(item, task) else item
      ]);
    } catch (_) {
      // Payload không hợp lệ sẽ được phục hồi bằng lần tải tasks sau.
    }
  }

  BookingModel _upsert(BookingModel booking, CareTaskModel task) {
    final tasks = [
      for (final old in booking.tasks)
        if (old.id == task.id) task else old
    ];
    if (!booking.tasks.any((old) => old.id == task.id)) {
      tasks.add(task);
      tasks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return booking.copyWith(
        tasks: tasks,
        needsReview: tasks.any((task) => task.isRequired && task.isSkipped));
  }
}
