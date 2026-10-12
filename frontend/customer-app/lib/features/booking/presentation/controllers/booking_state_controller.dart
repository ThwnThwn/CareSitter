import '../../data/models/booking_model.dart';

/// Cổng cập nhật cache của một phiên; delegate cũ không ghi vào phiên mới.
class BookingStateController {
  BookingStateController(
      {required this.userId,
      required this.read,
      required this.write,
      required bool Function() current})
      : _current = current;
  final String? userId;
  final List<BookingModel> Function() read;
  final void Function(List<BookingModel>) write;
  final bool Function() _current;
  bool _closed = false;
  bool get active => !_closed && _current();
  List<BookingModel> get items => active ? read() : const [];
  void close() => _closed = true;
  void replace(Iterable<BookingModel> items) {
    if (!active) return;
    write(items.toList()
      ..sort((a, b) {
        final byUpdated = b.updatedAt.compareTo(a.updatedAt);
        return byUpdated != 0 ? byUpdated : b.id.compareTo(a.id);
      }));
  }

  void apply(BookingModel item, {bool insert = false}) {
    if (!active) return;
    replace([
      if (insert) item,
      for (final old in items)
        if (old.id != item.id) old else if (!insert) item,
    ]);
  }

  List<BookingModel> merge(List<BookingModel> incoming) {
    if (!active || incoming.isEmpty) return const [];
    final indexed = {for (final item in items) item.id: item};
    final changed = <BookingModel>[];
    for (final item in incoming) {
      final old = indexed[item.id];
      if (old == null || item.syncVersion > old.syncVersion) {
        indexed[item.id] = item;
        changed.add(item);
      }
    }
    replace(indexed.values);
    return changed;
  }
}
