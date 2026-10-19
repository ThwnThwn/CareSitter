import 'package:caregiver_app/features/booking_chat/data/booking_chat_message.dart';

class BookingChatPage {
  const BookingChatPage(
    this.items,
    this.hasMoreBefore,
    this.hasMoreAfter,
    this.nextCursor,
    this.previousCursor,
    this.highWatermark,
    this.scopeVersion,
  );

  final List<BookingChatMessage> items;
  final bool hasMoreBefore;
  final bool hasMoreAfter;
  final String? nextCursor;
  final String? previousCursor;
  final int highWatermark;
  final int scopeVersion;
}
