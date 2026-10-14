import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/features/auth/data/repositories/recovery_repository.dart';
import 'package:caregiver_app/features/auth/presentation/screens/recovery_email_screen.dart';

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'A', isAuthenticated: true);
  void replaceSession() {
    state = const AsyncData(AuthState(userId: 'B', isAuthenticated: true));
  }
}

class _UnusedClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected HTTP');
}

class _Recovery extends RecoveryRepository {
  _Recovery() : super(_UnusedClient());
  String profileEmail = 'current@example.com';
  String? requestedEmail, requestedPassword;
  var requests = 0, confirms = 0;
  @override
  Future<Map<String, dynamic>> profile() async => {
        'email': profileEmail,
        'emailVerifiedAt': null,
        'hasPassword': true,
      };
  @override
  Future<RecoveryChallenge> requestEmail(String email, String? password) async {
    requests++;
    requestedEmail = email;
    requestedPassword = password;
    return const RecoveryChallenge('challenge', 600, 60, 'Đã yêu cầu mã.');
  }

  @override
  Future<Map<String, dynamic>> confirmEmail(String id, String code) async {
    confirms++;
    return {'email': requestedEmail, 'sessionsRevoked': false};
  }
}

void main() {
  late _Recovery repository;
  late ProviderContainer container;
  var closed = false;
  Future<void> close(WidgetTester tester) async {
    if (closed) return;
    closed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }

  Future<void> open(WidgetTester tester) async {
    closed = false;
    repository = _Recovery();
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      recoveryRepositoryProvider.overrideWithValue(repository),
    ]);
    await container.read(authStateProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecoveryEmailScreen())));
    await tester.pumpAndSettle();
    addTearDown(() => close(tester));
  }

  final email = find.byKey(const ValueKey('profile-recovery-email'));
  final code = find.byKey(const ValueKey('profile-email-code'));
  final password = find.ancestor(
      of: find.byWidgetPredicate((widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Mật khẩu hiện tại'),
      matching: find.byType(TextFormField));
  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'email/password/code validation and changing information retain drafts',
      (tester) async {
    await open(tester);
    await tester.enterText(email, 'invalid');
    await tester.pump();
    await submit(tester);
    expect(repository.requests, 0);
    expect(find.text('Vui lòng nhập email hợp lệ.'), findsOneWidget);
    await tester.enterText(email, 'new@example.com');
    await tester.pump();
    await submit(tester);
    expect(repository.requests, 0);
    expect(find.text('Nhập mật khẩu hiện tại để đổi email.'), findsOneWidget);
    await tester.enterText(password, 'CurrentPassword123');
    await submit(tester);
    expect(repository.requests, 1);
    expect(repository.requestedEmail, 'new@example.com');
    expect(repository.requestedPassword, 'CurrentPassword123');
    expect(find.text('Gửi lại sau 60s'), findsOneWidget);
    await tester.enterText(code, '1234');
    await submit(tester);
    expect(repository.confirms, 0);
    expect(find.text('Nhập đủ 6 chữ số.'), findsOneWidget);
    await tester.ensureVisible(find.text('Đổi thông tin'));
    await tester.tap(find.text('Đổi thông tin'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(email).controller!.text,
        'new@example.com');
    expect(tester.widget<TextFormField>(password).controller!.text,
        'CurrentPassword123');
    await submit(tester);
    expect(repository.requests, 2);
    expect(tester.widget<TextFormField>(code).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets(
      'session replacement clears sensitive drafts and reloads the email',
      (tester) async {
    await open(tester);
    await tester.enterText(email, 'new@example.com');
    await tester.pump();
    await tester.enterText(password, 'CurrentPassword123');
    await submit(tester);
    await tester.enterText(code, '123456');
    repository.profileEmail = 'next@example.com';
    (container.read(authStateProvider.notifier) as _Auth).replaceSession();
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(email).controller!.text,
        'next@example.com');
    expect(code, findsNothing);
    await tester.enterText(email, 'another@example.com');
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextFormField>(password).controller!.text, isEmpty);
    await tester.enterText(password, 'NextPassword123');
    await submit(tester);
    expect(tester.widget<TextFormField>(code).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
