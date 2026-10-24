import 'package:caresitter_customer/app/router/app_router.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState.initial();
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(isAuthenticated: true);
}

void main() {
  test('production route map parses creation and detail deep links', () {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_TestAuthNotifier.new),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    final booking = router.configuration.findMatch(Uri.parse(
      '/bookings/new?service-id=service-1&beneficiary-id=person-1',
    ));
    expect(booking.error, isNull);
    expect((booking.matches.last.route as GoRoute).path, AppRoutes.bookingNew);
    expect(booking.uri.queryParameters['service-id'], 'service-1');
    expect(booking.uri.queryParameters['beneficiary-id'], 'person-1');

    final beneficiary =
        router.configuration.findMatch(Uri.parse(AppRoutes.beneficiaryNew));
    expect(beneficiary.error, isNull);
    expect((beneficiary.matches.last.route as GoRoute).path,
        AppRoutes.beneficiaryNew);

    final detail = router.configuration.findMatch(Uri.parse(
      AppRoutes.bookingDetail('booking-1'),
    ));
    expect(detail.error, isNull);
    expect(detail.pathParameters['id'], 'booking-1');

    expect(router.configuration.findMatch(Uri.parse('/not-a-route')).error,
        isNotNull);

    final root = router.configuration.findMatch(Uri.parse(AppRoutes.root));
    expect(root.error, isNull);
    expect((root.matches.last.route as GoRoute).redirect, isNotNull);
  });

  test('legacy paths remain registered for redirect', () {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_TestAuthNotifier.new),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    for (final path in [
      AppRoutes.legacyBookingNew,
      AppRoutes.legacyBeneficiaryCreate,
    ]) {
      final match = router.configuration.findMatch(Uri.parse(path));
      expect(match.error, isNull, reason: path);
      expect((match.matches.last.route as GoRoute).redirect, isNotNull,
          reason: path);
    }
  });

  testWidgets('legacy booking redirect keeps its preselected IDs',
      (tester) async {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_TestAuthNotifier.new),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox.shrink();
    })));

    final uri = Uri.parse('/booking/new?serviceId=service-1');
    final route =
        router.configuration.findMatch(uri).matches.last.route as GoRoute;
    final state = GoRouterState(
      router.configuration,
      uri: uri,
      matchedLocation: uri.path,
      fullPath: route.path,
      pathParameters: const {},
      pageKey: const ValueKey('legacy-booking'),
    );
    expect(await route.redirect!(context, state),
        '/bookings/new?service-id=service-1');
  });

  testWidgets('unknown authenticated deep link shows the 404 page',
      (tester) async {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_AuthenticatedAuthNotifier.new),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    router.go('/not-a-route');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy trang này'), findsOneWidget);
  });
}
