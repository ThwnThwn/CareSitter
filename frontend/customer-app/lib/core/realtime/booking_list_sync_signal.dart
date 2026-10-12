/// Signal nhận từ SignalR 'BookingListSync' event — chỉ là tín hiệu, không chứa state.
class BookingListSyncSignal {
  final String bookingId;
  final int bookingVersion;
  final int cursor;
  final DateTime changedAt;

  const BookingListSyncSignal({
    required this.bookingId,
    required this.bookingVersion,
    required this.cursor,
    required this.changedAt,
  });

  factory BookingListSyncSignal.fromJson(Map<String, dynamic> json) =>
      BookingListSyncSignal(
        bookingId: json['bookingId']?.toString() ?? '',
        bookingVersion: (json['bookingVersion'] as num?)?.toInt() ?? 0,
        cursor: (json['cursor'] as num?)?.toInt() ?? 0,
        changedAt: DateTime.tryParse(json['changedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}
