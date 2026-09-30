import 'package:caresitter_customer/core/router/auth_route_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newly authenticated user is routed to the logo intro', () {
    expect(
      authRouteRedirect(location: '/auth/login', isAuthenticated: true),
      '/brand-intro',
    );
  });

  test('unauthenticated user cannot open the intro route', () {
    expect(
      authRouteRedirect(location: '/brand-intro', isAuthenticated: false),
      '/auth/login',
    );
  });

  test('intro remains available to an authenticated user and home is normal',
      () {
    expect(
      authRouteRedirect(location: '/brand-intro', isAuthenticated: true),
      isNull,
    );
    expect(
      authRouteRedirect(location: '/home', isAuthenticated: true),
      isNull,
    );
  });
}
