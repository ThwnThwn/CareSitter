import 'package:caresitter_customer/core/router/shell_scaffold.dart';
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
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, __, child) => ShellScaffold(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const Scaffold(body: Text('Trang chủ')),
            ),
          ],
        ),
        GoRoute(
          path: '/booking/new',
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
    final addRect = tester.getRect(find.byIcon(Icons.add_rounded));

    expect(addRect.top, greaterThanOrEqualTo(barRect.top));
    expect(addRect.bottom, lessThanOrEqualTo(barRect.bottom));
    expect(find.text('Đặt lịch'), findsOneWidget);

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
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, __, child) => ShellScaffold(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const Scaffold(body: Text('Trang chủ')),
            ),
          ],
        ),
        GoRoute(
          path: '/booking/new',
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

    expect(find.text('Chăm sóc viên'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
