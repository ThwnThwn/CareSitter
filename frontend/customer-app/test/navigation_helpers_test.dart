import 'package:caresitter_customer/app.dart';
import 'package:caresitter_customer/core/router/app_router.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter createRouter({String initialLocation = '/home'}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('Home marker'))),
        ),
        GoRoute(
          path: '/detail',
          builder: (_, __) => Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/home'),
            ),
            body: const Center(child: Text('Detail marker')),
          ),
        ),
      ],
    );
  }

  testWidgets('AppBackButton pops a pushed route', (tester) async {
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.push('/detail');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Home marker'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppBackButton uses fallback for a direct route', (tester) async {
    final router = createRouter(initialLocation: '/detail');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Home marker'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DiscardChangesGuard requires confirmation before leaving',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    late GoRouter router;
    router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('Home marker'))),
        ),
        GoRoute(
          path: '/editor',
          builder: (_, __) => DiscardChangesGuard(
            hasChanges: () => controller.text.isNotEmpty,
            fallbackRoute: '/home',
            builder: (context, requestExit) => Scaffold(
              appBar: AppBar(
                leading: AppCloseButton(
                  fallbackRoute: '/home',
                  onPressed: requestExit,
                ),
              ),
              body: TextField(controller: controller),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byType(TextField), 'Nội dung chưa lưu');

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ các thay đổi?'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục chỉnh sửa'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();

    expect(find.text('Home marker'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home and catalog do not overflow at 390 logical pixels',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CareSitterApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    container.read(appRouterProvider).push('/catalog');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
