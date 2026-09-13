import 'package:caregiver_app/core/push/notification_deep_link_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late NotificationDeepLinkService service;

  setUp(() {
    container = ProviderContainer();
    service = container.read(notificationDeepLinkServiceProvider);
  });

  tearDown(() => container.dispose());

  test('maps booking offers to caregiver shift details', () {
    expect(
      service.resolveRoute({
        'bookingId': 'booking-123',
        'type': 'BOOKING_OFFER',
      }),
      '/shifts/booking-123',
    );
  });

  test('maps completed shifts to summary', () {
    expect(
      service.resolveRoute({
        'bookingId': 'booking-123',
        'status': 'completed',
      }),
      '/shifts/booking-123/summary',
    );
  });

  test('normalizes legacy booking routes and rejects external links', () {
    expect(
      service.resolveRoute({'deepLink': '/bookings/booking-123'}),
      '/shifts/booking-123',
    );
    expect(
      service.resolveRoute({'deepLink': 'https://example.com/phishing'}),
      isNull,
    );
  });
}
