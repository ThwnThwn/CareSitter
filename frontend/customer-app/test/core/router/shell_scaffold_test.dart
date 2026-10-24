import 'package:caresitter_customer/app/router/shell_scaffold.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('center booking action stays inside the navigation bar',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (_, __, child) => ShellScaffold(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const Scaffold(
                body: SizedBox.expand(
                  key: ValueKey('home-body'),
                  child: Text('Trang chủ'),
                ),
              ),
            ),
            GoRoute(
              path: AppRoutes.nutrition,
              builder: (_, __) => const Scaffold(body: Text('Trang thực đơn')),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.bookingNew,
          builder: (_, __) => const Scaffold(body: Text('Tạo lịch mới')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final barRect = tester.getRect(find.byType(BottomAppBar));
    final bodyRect = tester.getRect(find.byKey(const ValueKey('home-body')));
    final addRect = tester.getRect(find.byIcon(Icons.add_rounded));

    expect(bodyRect.bottom, lessThanOrEqualTo(barRect.top));
    // The circular booking action may optically rise a few pixels above the
    // bar, but must stay attached to it rather than floating over content.
    expect(addRect.top, greaterThanOrEqualTo(barRect.top - AppSpacing.sm));
    expect(addRect.bottom, lessThanOrEqualTo(barRect.bottom));
    expect(find.text('Đặt lịch'), findsOneWidget);
    expect(find.text('Thực đơn'), findsOneWidget);

    await tester.tap(find.text('Thực đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Trang thực đơn'), findsOneWidget);

    router.go(AppRoutes.home);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Tạo lịch mới'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation reflows at 320 px with enlarged text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (_, __, child) => ShellScaffold(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const Scaffold(body: Text('Trang chủ')),
            ),
            GoRoute(
              path: AppRoutes.nutrition,
              builder: (_, __) => const Scaffold(body: Text('Trang thực đơn')),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.bookingNew,
          builder: (_, __) => const Scaffold(body: Text('Tạo lịch mới')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
            ),
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chăm sóc viên'), findsNothing);
    expect(find.text('Thực đơn'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
