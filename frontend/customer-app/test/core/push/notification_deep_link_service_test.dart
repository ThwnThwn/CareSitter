import 'package:caresitter_customer/app/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late NotificationDeepLinkService service;

  setUp(() {
    container = ProviderContainer(overrides: [
      notificationDeepLinkServiceProvider
          .overrideWith(createNotificationDeepLinkService),
    ]);
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
    expect(service.resolveRoute({'type': 'PAYMENT'}), '/bookings');
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

  test('payment callbacks retain safe identifiers and never trust supplied success',
      () {
    expect(
        service.resolveRoute({
          'deepLink':
              'caresitter-customer:/payment-result?bookingId=booking-123&intentId=intent-123&result=success&redirect=https://evil.example'
        }),
        '/payment-result?bookingId=booking-123&intentId=intent-123&result=pending');
    expect(
        service.resolveRoute({
          'deepLink': 'caresitter-customer://payment-result?bookingId=booking-123'
        }),
        '/payment-result?bookingId=booking-123&result=pending');
    expect(
        service.resolveRoute({
          'deepLink':
              'https://evil.example/payment-result?bookingId=booking-123&result=success'
        }),
        isNull);
    expect(
        service.resolveRoute({
          'deepLink': 'caresitter-customer:/payment-result?bookingId=../settings'
        }),
        isNull);
  });
}
