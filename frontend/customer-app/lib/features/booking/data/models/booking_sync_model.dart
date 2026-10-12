export 'package:caresitter_customer/core/realtime/booking_list_sync_signal.dart';

/// Response từ GET /api/v1/bookings/sync
class BookingSyncResponse {
  final List<dynamic> items; // BookingModel instances
  final int nextCursor;
  final DateTime serverTime;
  final bool hasMore;
  final bool resetRequired;

  const BookingSyncResponse({
    required this.items,
    required this.nextCursor,
    required this.serverTime,
    required this.hasMore,
    required this.resetRequired,
  });
}
