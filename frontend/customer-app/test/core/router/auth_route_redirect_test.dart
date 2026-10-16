import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/auth_route_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const paymentReturn =
      '/payment-result?bookingId=booking-123&intentId=intent-123&result=pending&provider=PAYOS';

  testWidgets('payment return waits for persisted auth before building a route',
      (tester) async {
    final session = Completer<bool>();
    var loginBuilds = 0;
    var resultBuilds = 0;
    final router = GoRouter(
      initialLocation: paymentReturn,
      redirect: (_, state) => authSessionRouteRedirect(
          location: state.uri.toString(), isAuthenticated: session.future),
      routes: [
        GoRoute(
            path: '/auth/login',
            builder: (_, __) {
              loginBuilds++;
              return const Text('Login');
            }),
        GoRoute(
            path: '/payment-result',
            builder: (_, state) {
              resultBuilds++;
              return Text(state.uri.queryParameters['intentId']!);
            }),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(loginBuilds, 0);
    expect(resultBuilds, 0);
    session.complete(true);
    await tester.pumpAndSettle();
    expect(loginBuilds, 0);
    expect(find.text('intent-123'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.toString(), paymentReturn);
  });

  test('expired session retains the payment return after sign-in', () {
    final login =
        authRouteRedirect(location: paymentReturn, isAuthenticated: false)!;
    expect(Uri.parse(login).path, '/auth/login');
    expect(authRouteRedirect(location: login, isAuthenticated: false), isNull);
    expect(authRouteRedirect(location: login, isAuthenticated: true),
        paymentReturn);
  });

  test('auth storage errors still require sign-in and retain the payment',
      () async {
    final login = await authSessionRouteRedirect(
        location: paymentReturn,
        isAuthenticated: Future.error(StateError('storage')));
    expect(Uri.parse(login!).queryParameters['returnTo'], paymentReturn);
  });

  test('sign-in ignores external or unrelated return destinations', () {
    for (final target in [
      'https://attacker.example/payment-result',
      '//attacker.example/payment-result',
      '/settings',
      '/payment-result#external'
    ]) {
      final login =
          Uri(path: '/auth/login', queryParameters: {'returnTo': target});
      expect(
          authRouteRedirect(location: login.toString(), isAuthenticated: true),
          '/brand-intro');
    }
  });
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
