import 'package:caregiver_app/app/onboarding/onboarding_screen.dart';
import 'package:caregiver_app/app/onboarding/onboarding_status.dart';
import 'package:caregiver_app/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Stitch onboarding opens registration and persists completion',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(initialLocation: AppRoutes.onboarding, routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(
          registerRoute: AppRoutes.register,
          loginRoute: AppRoutes.login,
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const Scaffold(body: Text('Registration target')),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const Scaffold(body: Text('Login target')),
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Chăm sóc an tâm ngay tại nhà'), findsOneWidget);
    expect(find.text('Bắt đầu ngay'), findsOneWidget);
    expect(find.text('Tôi đã có tài khoản'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(await OnboardingStatus.hasCompleted(), isFalse);

    await tester.tap(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();
    expect(find.text('Registration target'), findsOneWidget);
    expect(await OnboardingStatus.hasCompleted(), isTrue);
  });

  testWidgets('existing account opens login on a narrow phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: AppRoutes.onboarding, routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(
          registerRoute: AppRoutes.register,
          loginRoute: AppRoutes.login,
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const Scaffold(body: Text('Login target')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tôi đã có tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Login target'), findsOneWidget);
  });
}
