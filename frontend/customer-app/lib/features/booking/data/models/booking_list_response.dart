import 'booking_model.dart';

class BookingListResponse {
  final List<BookingModel> items;
  final int total;
  final int page;
  final int pageSize;

  /// Cursor mới nhất của customer — client lưu để bắt đầu delta sync.
  final int syncCursor;

  const BookingListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    this.syncCursor = 0,
  });

  factory BookingListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(BookingModel.fromJson)
            .toList()
        : <BookingModel>[];
    return BookingListResponse(
      items: items,
      total: _int(json['total']) ?? items.length,
      page: _int(json['page']) ?? 1,
      pageSize: _int(json['pageSize']) ?? items.length,
      syncCursor: _int(json['syncCursor']) ?? 0,
    );
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
