import 'package:caregiver_app/features/booking_chat/data/booking_chat_meta.dart';
import 'package:caregiver_app/features/booking_chat/data/booking_chat_page.dart';

abstract interface class BookingChatRepositoryPort {
  Future<BookingChatMeta> metadata(String bookingId);
  Future<BookingChatPage> messages(
    String bookingId, {
    String? afterCursor,
    String? beforeCursor,
    int limit = 50,
  });
  Future<String> sendText(
    String bookingId,
    String epochId,
    String text,
    String idempotencyKey,
  );
  Future<String> sendQuick(
    String bookingId,
    String epochId,
    String templateKey,
    int templateVersion,
    String idempotencyKey, {
    Map<String, String>? params,
  });
  Future<void> markRead(
    String bookingId,
    String epochId,
    String lastReadMessageId,
  );
}
