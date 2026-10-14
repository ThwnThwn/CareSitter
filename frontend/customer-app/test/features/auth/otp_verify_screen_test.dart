import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/otp_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/otp_verify_screen.dart';

void main() {
  Finder digit(int index) => find.descendant(
      of: find.byKey(ValueKey('otp-digit-$index')),
      matching: find.byType(TextField));

  testWidgets(
      'narrow OTP form advances focus, clears a rejected code and accepts retry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    var writes = 0;
    final submitted = <String>[];
    final overrides = [
      otpControllerProvider.overrideWith((ref, email) => OtpController(
          send: () async {},
          verify: (code) async {
            writes++;
            submitted.add(code);
            if (writes == 1) throw StateError('wrong code');
          })),
    ];
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
            home: OtpVerifyScreen(email: 'user@example.com'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(digit(0), '1');
    expect(tester.widget<TextField>(digit(1)).focusNode!.hasFocus, isTrue);
    for (var index = 1; index < 6; index++) {
      await tester.enterText(digit(index), '${index + 1}');
    }
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.textContaining('Mã OTP không đúng'), findsOneWidget);
    for (var index = 0; index < 6; index++) {
      expect(tester.widget<TextField>(digit(index)).controller!.text, isEmpty);
    }
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    for (var index = 0; index < 6; index++) {
      await tester.enterText(digit(index), '${index + 1}');
    }
    await tester.pumpAndSettle();
    expect(submitted, ['123456', '123456']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a reused email route clears the old code and ignores its late verification',
      (tester) async {
    final response = Completer<void>();
    final overrides = [
      otpControllerProvider.overrideWith((ref, email) =>
          OtpController(send: () async {}, verify: (_) => response.future)),
    ];
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    Widget app(String email) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: OtpVerifyScreen(email: email)));
    await tester.pumpWidget(app('first@example.com'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 6; index++) {
      await tester.enterText(digit(index), '${index + 1}');
    }
    await tester.pump();
    await tester.pumpWidget(app('next@example.com'));
    await tester.pump();
    for (var index = 0; index < 6; index++) {
      expect(tester.widget<TextField>(digit(index)).controller!.text, isEmpty);
    }
    await tester.enterText(digit(0), '7');
    await tester.enterText(digit(1), '8');
    response.completeError(StateError('late old response'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(digit(0)).controller!.text, '7');
    expect(tester.widget<TextField>(digit(1)).controller!.text, '8');
    expect(tester.takeException(), isNull);
  });
}
