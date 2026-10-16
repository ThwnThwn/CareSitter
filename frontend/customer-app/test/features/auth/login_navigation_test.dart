import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('navigates after one successful login tap', (tester) async {
    late _SuccessfulLoginController controller;
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: [
        GoRoute(
          path: '/auth/login',
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: '/brand-intro',
          builder: (_, __) => const Scaffold(body: Text('Brand intro')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loginControllerProvider.overrideWith(() {
            controller = _SuccessfulLoginController();
            return controller;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.enterText(
        find.byType(TextFormField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.text('Ghi nhớ đăng nhập'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/brand-intro');
    expect(find.text('Brand intro'), findsOneWidget);
    expect(controller.rememberSession, isFalse);
  });
}

class _SuccessfulLoginController extends LoginController {
  bool? rememberSession;

  @override
  LoginState build() => const LoginState();

  @override
  Future<bool> login({
    required String email,
    required String password,
    bool rememberSession = true,
  }) async {
    this.rememberSession = rememberSession;
    return true;
  }
}
