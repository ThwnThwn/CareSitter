import '../../data/models/shift_model.dart';

class ShiftCacheController {
  ShiftCacheController(
      {required this.active, required this.read, required this.write});
  final bool Function() active;
  final List<ShiftModel> Function() read;
  final void Function(List<ShiftModel>) write;
  List<ShiftModel> get items => active() ? read() : const [];
  void replace(List<ShiftModel> items) {
    if (active()) write(items);
  }

  void patch(String id, ShiftModel Function(ShiftModel) update) => replace([
        for (final item in items)
          if (item.id == id) update(item) else item
      ]);
  void remove(String id) => replace([
        for (final item in items)
          if (item.id != id) item
      ]);
  void replaceTasks(String id, List<CareTaskModel> tasks) =>
      patch(id, (item) => item.copyWith(tasks: tasks));
  void upsertTask(String id, CareTaskModel task, {bool insert = true}) =>
      patch(id, (item) {
        final exists = item.tasks.any((old) => old.id == task.id);
        return item.copyWith(tasks: [
          for (final old in item.tasks)
            if (old.id == task.id) task else old,
          if (insert && !exists) task,
        ]);
      });
}
