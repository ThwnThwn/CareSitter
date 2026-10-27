import 'dart:ui' as ui;

import 'package:caresitter_customer/app/router/shell_nav_item.dart';
import 'package:caresitter_customer/app/router/shell_scaffold.dart';
import 'package:caresitter_customer/app/router/shell_stitch_bottom_bar.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('bottom safe area keeps the navigation surface color',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);

    final boundaryKey = GlobalKey();
    const tabs = [
      ShellNavItem(icon: Icons.home_outlined, label: 'Trang chủ', path: '/'),
      ShellNavItem(
          icon: Icons.calendar_month_outlined,
          label: 'Lịch hẹn',
          path: '/bookings'),
      ShellNavItem(
          icon: Icons.restaurant_menu_outlined,
          label: 'Thực đơn',
          path: '/nutrition'),
      ShellNavItem(
          icon: Icons.person_outline_rounded,
          label: 'Hồ sơ',
          path: '/settings'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RepaintBoundary(
          key: boundaryKey,
          child: Scaffold(
            backgroundColor: AppColors.background,
            bottomNavigationBar: ShellStitchBottomBar(
              selectedIndex: 0,
              tabs: tabs,
              onTabSelected: (_) {},
              onCreateBooking: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pixelColor = await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final rgba = bytes!.buffer.asUint8List();
      final pixelOffset =
          ((image.height - 10) * image.width + image.width ~/ 2) * 4;
      return Color.fromARGB(
        rgba[pixelOffset + 3],
        rgba[pixelOffset],
        rgba[pixelOffset + 1],
        rgba[pixelOffset + 2],
      );
    });

    expect(pixelColor, AppColors.surface);
  });

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

    final barRect = tester.getRect(find.byType(ShellStitchBottomBar));
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
