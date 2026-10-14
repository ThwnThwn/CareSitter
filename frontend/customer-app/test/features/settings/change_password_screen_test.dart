import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/password_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/screens/change_password_screen.dart';

class _Auth extends AuthNotifier {
  int generation = 0;
  int logouts = 0;
  @override
  int get sessionGeneration => generation;
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'A', isAuthenticated: true);
  void relogin() {
    generation++;
    state = const AsyncData(
        AuthState(userId: 'A', isAuthenticated: true, accessToken: 'next'));
  }

  @override
  Future<void> logout() async => logouts++;
}

void main() {
  late _Auth auth;
  late Completer<bool> response;
  var writes = 0;
  Future<void> open(WidgetTester tester) async {
    response = Completer<bool>();
    writes = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      authStateProvider.overrideWith(() => auth = _Auth()),
      passwordControllerProvider.overrideWith((ref) => PasswordController(
            isCurrent: () => true,
            write: (
                {required currentPassword,
                required newPassword,
                cancellation}) {
              writes++;
              return response.future;
            },
          )),
    ], child: const MaterialApp(home: ChangePasswordScreen())));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ChangePasswordScreen)));
    await container.read(authStateProvider.future);
    await tester.pumpAndSettle();
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  }

  Future<void> enterAndSubmit(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'OldPassword123');
    await tester.enterText(fields.at(1), 'NewPassword123');
    await tester.enterText(fields.at(2), 'NewPassword123');
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
  }

  testWidgets(
      'validation stops writes and each password field retains its draft',
      (tester) async {
    await open(tester);
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('Vui lòng xác nhận mật khẩu'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'NewPassword123');
    final visibility = find.byIcon(Icons.visibility_off_outlined);
    await tester.ensureVisible(visibility.at(1));
    await tester.tap(visibility.at(1));
    await tester.pump();
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: fields.at(1), matching: find.byType(TextField)))
            .obscureText,
        isFalse);
    expect(tester.widget<TextFormField>(fields.at(1)).controller!.text,
        'NewPassword123');
  });

  testWidgets('delayed success cannot log out a newer login of the same user',
      (tester) async {
    await open(tester);
    await enterAndSubmit(tester);
    expect(writes, 1);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    response.complete(true);
    await tester.pump();
    auth.relogin();
    await tester.pump(const Duration(seconds: 2));
    expect(auth.logouts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'leaving during the success delay does not access a disposed screen',
      (tester) async {
    await open(tester);
    await enterAndSubmit(tester);
    response.complete(true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(auth.logouts, 0);
    expect(tester.takeException(), isNull);
  });
}
