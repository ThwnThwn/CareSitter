import 'package:caregiver_app/features/booking_chat/data/booking_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message rejects missing identity and malformed server timestamp', () {
    expect(
        () => BookingChatMessage.fromJson({
              'epochId': 'epoch',
              'sequence': 1,
              'kind': 'text',
              'body': 'hello',
              'createdAt': 'not-a-date',
              'isMine': false,
            }),
        throwsFormatException);
  });

  test('metadata rejects malformed server timestamp', () {
    expect(
        () => BookingChatMeta.fromJson({
              'featureEnabled': true,
              'bookingId': 'booking',
              'state': 'open',
              'serverNow': 'not-a-date',
            }),
        throwsFormatException);
  });
}
