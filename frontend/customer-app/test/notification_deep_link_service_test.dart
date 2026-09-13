import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
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

  test('maps active booking notifications to tracking', () {
    expect(
      service.resolveRoute({
        'bookingId': 'booking-123',
        'status': 'en_route',
      }),
      '/bookings/booking-123/tracking',
    );
  });

  test('maps payment without booking id to payment settings', () {
    expect(service.resolveRoute({'type': 'PAYMENT'}), '/settings/payment');
  });

  test('accepts only known app routes', () {
    expect(
      service.resolveRoute({'deepLink': 'caresitter://bookings/booking-123'}),
      '/bookings/booking-123',
    );
    expect(
      service.resolveRoute({'deepLink': 'https://example.com/phishing'}),
      isNull,
    );
  });
}
