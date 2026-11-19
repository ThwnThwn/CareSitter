import '../../data/models/shift_model.dart';

class ShiftCacheController {
  ShiftCacheController(
      {required this.active, required this.read, required this.write});
  final bool Function() active;
  final List<ShiftModel> Function() read;
  final void Function(List<ShiftModel>) write;
  final _retainedIds = <String>{};
  int _revision = 0;
  int get revision => _revision;
  List<ShiftModel> get items => active() ? read() : const [];
  ShiftModel? find(String id) =>
      items.where((item) => item.id == id).firstOrNull;

  void replace(List<ShiftModel> items) {
    if (active()) write(items);
  }

  void retain(ShiftModel item) {
    if (!active() || find(item.id) != null) return;
    _revision++;
    _retainedIds.add(item.id);
    replace([...items, item]);
  }

  void replacePage(List<ShiftModel> loaded) {
    final ids = loaded.map((item) => item.id).toSet();
    replace([
      ...loaded,
      ...items.where(
          (item) => _retainedIds.contains(item.id) && !ids.contains(item.id)),
    ]);
  }

  void patch(String id, ShiftModel Function(ShiftModel) update) {
    _revision++;
    _patch(id, update);
  }

  void _patch(String id, ShiftModel Function(ShiftModel) update) => replace([
        for (final item in items)
          if (item.id == id) update(item) else item
      ]);
  void remove(String id) {
    _revision++;
    _retainedIds.remove(id);
    replace([
      for (final item in items)
        if (item.id != id) item
    ]);
  }

  void replaceTasks(String id, List<CareTaskModel> tasks) =>
      _patch(id, (item) => item.copyWith(tasks: tasks));
  void upsertTask(String id, CareTaskModel task) => _patch(id, (item) {
        final exists = item.tasks.any((old) => old.id == task.id);
        return item.copyWith(tasks: [
          for (final old in item.tasks)
            if (old.id == task.id) task else old,
          if (!exists) task,
        ]);
      });
}
