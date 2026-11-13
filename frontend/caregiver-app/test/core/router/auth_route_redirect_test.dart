import 'package:caregiver_app/core/router/auth_route_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new install, returning visitor, and active session', () async {
    expect(
      await caregiverAuthRouteRedirect(
        location: '/onboarding',
        isAuthenticated: Future.value(false),
        hasCompletedOnboarding: Future.value(false),
      ),
      isNull,
    );
    expect(
      await caregiverAuthRouteRedirect(
        location: '/onboarding',
        isAuthenticated: Future.value(false),
        hasCompletedOnboarding: Future.value(true),
      ),
      '/auth/phone',
    );
    expect(
      await caregiverAuthRouteRedirect(
        location: '/onboarding',
        isAuthenticated: Future.value(true),
        hasCompletedOnboarding: Future.value(false),
      ),
      '/home',
    );
  });

  test('auth deep links remain usable before onboarding', () async {
    for (final path in ['/auth/phone', '/auth/register']) {
      expect(
        await caregiverAuthRouteRedirect(
          location: path,
          isAuthenticated: Future.value(false),
          hasCompletedOnboarding: Future.value(false),
        ),
        isNull,
      );
    }
    expect(
      await caregiverAuthRouteRedirect(
        location: '/shifts',
        isAuthenticated: Future.value(false),
      ),
      '/auth/phone',
    );
  });

  test('waits for persisted session instead of flashing login', () async {
    final session = Future<bool>.delayed(
      const Duration(milliseconds: 1),
      () => true,
    );
    expect(
      await caregiverAuthRouteRedirect(
        location: '/onboarding',
        isAuthenticated: session,
      ),
      '/home',
    );
  });
}
