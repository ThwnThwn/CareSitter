import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/support_screen.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_support_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('profile support entry opens the online chat channel',
      (tester) async {
    final router = GoRouter(initialLocation: AppRoutes.settings, routes: [
      GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(child: SettingsSupportSection()))),
      GoRoute(
          path: AppRoutes.support, builder: (_, __) => const SupportScreen()),
      GoRoute(
          path: AppRoutes.supportChat,
          builder: (_, __) =>
              const Scaffold(body: Text('Support conversation'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            theme: AppTheme.lightTheme, routerConfig: router)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Liên hệ hỗ trợ'));
    await tester.pumpAndSettle();
    expect(find.byType(SupportScreen), findsOneWidget);
    await tester.tap(find.text('Bắt đầu chat'));
    await tester.pumpAndSettle();
    expect(find.text('Support conversation'), findsOneWidget);
  });
}
