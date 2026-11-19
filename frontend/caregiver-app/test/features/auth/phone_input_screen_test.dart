import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/google_login_controller.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/login_controller.dart';
import 'package:caregiver_app/features/auth/presentation/screens/phone_input_screen.dart';

class _Login implements LoginController {
  int logins = 0, requests = 0;
  String? identifier, password, email;
  final response = Completer<void>();
  @override
  Future<void> loginWithPassword(String value, String secret) {
    logins++;
    identifier = value;
    password = secret;
    return response.future;
  }

  @override
  Future<void> requestOtp(String value) async {
    requests++;
    email = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected action');
}

class _Google implements GoogleLoginController {
  var attempts = 0;
  var pending = Completer<void>();

  @override
  Future<void> signIn() {
    attempts++;
    return pending.future;
  }

  @override
  void dispose() {}
}

void main() {
  late _Login login;
  Future<void> open(WidgetTester tester, {_Google? google}) async {
    login = _Login();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const PhoneInputScreen()),
      GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Trang chủ'))),
      GoRoute(
          path: '/auth/otp',
          builder: (_, state) =>
              Scaffold(body: Text('Mã OTP cho ${state.extra}'))),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      loginControllerProvider.overrideWithValue(login),
      if (google != null)
        googleLoginControllerProvider.overrideWith((ref) => google),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
  }

  Future<void> submit(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('Google sign-in opens with empty fields and resets after cancel',
      (tester) async {
    final google = _Google();
    await open(tester, google: google);
    await submit(tester, 'Tiếp tục với Google');
    expect(google.attempts, 1);
    final button = find.widgetWithText(OutlinedButton, 'Đang đăng nhập…');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(login.logins, 0);

    google.pending.completeError(
      const AppApiException(message: 'Đã đóng Google', isCancelled: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập chưa thành công'), findsNothing);
    google.pending = Completer<void>();
    await submit(tester, 'Tiếp tục với Google');
    expect(google.attempts, 2);
    google.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
  });

  testWidgets(
      'password login validates input and blocks a repeated submit while pending',
      (tester) async {
    await open(tester);
    await submit(tester, 'Đăng nhập');
    expect(login.logins, 0);
    await tester.enterText(find.byType(TextFormField).first, '0901234567');
    await tester.enterText(find.byType(TextFormField).last, 'short');
    await submit(tester, 'Đăng nhập');
    expect(login.logins, 0);
    await tester.enterText(find.byType(TextFormField).last, 'Password123');
    await submit(tester, 'Đăng nhập');
    expect(login.logins, 1);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(login.logins, 1);
    expect(login.identifier, '0901234567');
    expect(login.password, 'Password123');
    login.response.complete();
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'switching to OTP changes validation and sends a normalized email to its route',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Mã OTP'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '0901234567');
    await submit(tester, 'Gửi mã OTP');
    expect(login.requests, 0);
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), ' USER@example.com ');
    await submit(tester, 'Gửi mã OTP');
    await tester.pumpAndSettle();
    expect(login.requests, 1);
    expect(login.email, 'user@example.com');
    expect(find.text('Mã OTP cho user@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
