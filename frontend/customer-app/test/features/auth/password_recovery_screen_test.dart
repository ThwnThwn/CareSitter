import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/auth/data/repositories/recovery_repository.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/password_recovery_screen.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/recovery_email_screen.dart';

class FakeRecoveryRepository extends RecoveryRepository {
  FakeRecoveryRepository(super.client);
  int requests = 0, verifies = 0, resets = 0;
  bool failVerify = false, failReset = false;
  int grantSeconds = 300;
  Completer<RecoveryChallenge>? pending;
  String? usedToken, usedPassword;
  @override
  Future<RecoveryChallenge> request(String email) async {
    requests++;
    if (pending != null) return pending!.future;
    return const RecoveryChallenge('challenge', 600, 60,
        'Nếu tài khoản đủ điều kiện, mã sẽ được gửi tới email này.');
  }

  @override
  Future<RecoveryGrant> verify(String challengeId, String code) async {
    verifies++;
    if (failVerify) {
      throw DioException(
          requestOptions: RequestOptions(path: '/verify'),
          response: Response(
              requestOptions: RequestOptions(path: '/verify'),
              statusCode: 400,
              data: {'detail': 'Mã không hợp lệ hoặc đã hết hạn.'}));
    }
    return RecoveryGrant('limited-reset-token', grantSeconds);
  }

  @override
  Future<void> reset(String token, String password, String confirmation) async {
    resets++;
    usedToken = token;
    usedPassword = password;
    if (failReset) {
      throw DioException(
          requestOptions: RequestOptions(path: '/reset'),
          type: DioExceptionType.connectionError);
    }
  }

  @override
  Future<Map<String, dynamic>> profile() async => {
        'email': 'care@example.com',
        'emailVerifiedAt': null,
        'hasPassword': true
      };
  @override
  Future<RecoveryChallenge> requestEmail(
          String email, String? password) async =>
      const RecoveryChallenge('email-challenge', 600, 60, 'Đã yêu cầu mã.');
  @override
  Future<Map<String, dynamic>> confirmEmail(
          String challengeId, String code) async =>
      {'email': 'care@example.com', 'sessionsRevoked': false};
}

void main() {
  late FakeRecoveryRepository repository;
  Future<void> pumpScreen(WidgetTester tester,
      {Size size = const Size(430, 932),
      double scale = 1,
      bool profile = false,
      void Function(FakeRecoveryRepository)? configure}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          recoveryRepositoryProvider.overrideWith((ref) {
            repository = FakeRecoveryRepository(DioClient(ref));
            configure?.call(repository);
            return repository;
          }),
        ],
        child: MaterialApp(
          theme: ThemeData(
              colorSchemeSeed: const Color(0xFF006B5B), useMaterial3: true),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: profile
              ? const RecoveryEmailScreen()
              : const PasswordRecoveryScreen(),
        )));
    await tester.pumpAndSettle();
    final context = tester.element(
        find.byType(profile ? RecoveryEmailScreen : PasswordRecoveryScreen));
    ProviderScope.containerOf(context).read(recoveryRepositoryProvider);
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.byType(FilledButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> reachPassword(WidgetTester tester) async {
    await tester.enterText(
        find.byKey(const ValueKey('recovery-email')), 'care@example.com');
    await submit(tester);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-code')), '123456');
    await submit(tester);
  }

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(1024, 768)
  ]) {
    testWidgets(
        'three steps remain readable at ${size.width} with enlarged text',
        (tester) async {
      await pumpScreen(tester, size: size, scale: 1.4);
      expect(tester.takeException(), isNull);
      await reachPassword(tester);
      expect(find.byKey(const ValueKey('recovery-password')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('validates email before calling API', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-email')), 'not-email');
    await submit(tester);
    expect(repository.requests, 0);
    expect(find.text('Vui lòng nhập email hợp lệ.'), findsOneWidget);
  });
  testWidgets(
      'successful flow sends a limited token and clears password fields',
      (tester) async {
    await pumpScreen(tester);
    await reachPassword(tester);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-password')), 'NewPassword456');
    await tester.enterText(find.byKey(const ValueKey('recovery-confirmation')),
        'WrongPassword456');
    await submit(tester);
    expect(repository.resets, 0);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-confirmation')), 'NewPassword456');
    await submit(tester);
    expect(repository.usedToken, 'limited-reset-token');
    expect(repository.usedPassword, 'NewPassword456');
    expect(find.text('Đã đổi mật khẩu'), findsOneWidget);
    expect(find.text('Về đăng nhập'), findsOneWidget);
    expect(find.byKey(const ValueKey('recovery-password')), findsNothing);
  });
  testWidgets('wrong code stays on code step and resend has countdown',
      (tester) async {
    await pumpScreen(tester, configure: (repo) => repo.failVerify = true);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-email')), 'care@example.com');
    await submit(tester);
    expect(find.textContaining('Gửi lại sau'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-code')), '123456');
    await submit(tester);
    expect(find.text('Mã không hợp lệ hoặc đã hết hạn.'), findsOneWidget);
    expect(find.byKey(const ValueKey('recovery-password')), findsNothing);
    expect(repository.resets, 0);
  });
  testWidgets('network error permits retry without discarding reset grant',
      (tester) async {
    await pumpScreen(tester);
    await reachPassword(tester);
    repository.failReset = true;
    await tester.enterText(
        find.byKey(const ValueKey('recovery-password')), 'NewPassword456');
    await tester.enterText(
        find.byKey(const ValueKey('recovery-confirmation')), 'NewPassword456');
    await submit(tester);
    expect(find.textContaining('Không thể kết nối'), findsOneWidget);
    repository.failReset = false;
    await submit(tester);
    expect(repository.resets, 2);
    expect(repository.usedToken, 'limited-reset-token');
    expect(find.text('Đã đổi mật khẩu'), findsOneWidget);
  });
  testWidgets('expired grant blocks reset and restart clears sensitive fields',
      (tester) async {
    await pumpScreen(tester, configure: (repo) => repo.grantSeconds = 0);
    await reachPassword(tester);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-password')), 'NewPassword456');
    await tester.enterText(
        find.byKey(const ValueKey('recovery-confirmation')), 'NewPassword456');
    await submit(tester);
    expect(repository.resets, 0);
    expect(
        find.textContaining('Thời gian đặt mật khẩu đã hết'), findsOneWidget);
    await tester.ensureVisible(find.text('Bắt đầu lại'));
    await tester.tap(find.text('Bắt đầu lại'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recovery-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('recovery-password')), findsNothing);
  });
  testWidgets('busy request cannot send a second request', (tester) async {
    final pending = Completer<RecoveryChallenge>();
    await pumpScreen(tester, configure: (repo) => repo.pending = pending);
    await tester.enterText(
        find.byKey(const ValueKey('recovery-email')), 'care@example.com');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repository.requests, 1);
    pending.complete(const RecoveryChallenge(
        'challenge', 600, 60, 'Nếu tài khoản đủ điều kiện, mã sẽ được gửi.'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recovery-code')), findsOneWidget);
  });
  testWidgets('profile email verification updates ownership status',
      (tester) async {
    await pumpScreen(tester,
        profile: true, size: const Size(320, 568), scale: 1.4);
    expect(find.text('Chưa xác minh'), findsOneWidget);
    await submit(tester);
    await tester.enterText(
        find.byKey(const ValueKey('profile-email-code')), '123456');
    await submit(tester);
    expect(find.text('Đã xác minh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
