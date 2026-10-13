import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/registration_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/register_screen_error_banner.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/registration_form.dart';

Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label);

Future<void> fill(WidgetTester tester) async {
  for (final entry in {
    'Họ và tên': 'Khách kiểm thử',
    'Email': 'customer@example.com',
    'Số điện thoại': '0901234567',
    'Mật khẩu': 'Password1',
    'Xác nhận mật khẩu': 'Password1',
  }.entries) {
    await tester.ensureVisible(field(entry.key));
    await tester.enterText(field(entry.key), entry.value);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
}

Future<void> submit(WidgetTester tester) async {
  final button = find.byType(ElevatedButton);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Widget harness({
  required Future<void> Function(RegisterRequest) register,
  required VoidCallback onRegistered,
  double textScale = 1,
}) =>
    ProviderScope(
      overrides: [
        registrationControllerProvider
            .overrideWith((_) => RegistrationController(register)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
            builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: Scaffold(
                      body: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.section),
                    child: RegistrationForm(onRegistered: onRegistered),
                  )),
                )),
      ),
    );

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('registration retains input after a failed write at width $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final requests = <RegisterRequest>[];
      var registered = 0;
      await tester.pumpWidget(harness(
        textScale: 1.8,
        onRegistered: () => registered++,
        register: (request) async {
          requests.add(request);
          if (requests.length == 1) throw StateError('temporary failure');
        },
      ));
      await tester.pumpAndSettle();
      await submit(tester);
      expect(requests, isEmpty);
      await fill(tester);
      await submit(tester);
      expect(find.byType(RegisterScreenErrorBanner), findsOneWidget);
      expect(tester.widget<TextField>(field('Email')).controller!.text,
          'customer@example.com');
      expect(registered, 0);
      await submit(tester);
      expect(requests, hasLength(2));
      expect(requests.last.fullName, 'Khách kiểm thử');
      expect(registered, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('leaving a pending registration suppresses success navigation',
      (tester) async {
    final pending = Completer<void>();
    var writes = 0;
    var registered = 0;
    await tester.pumpWidget(harness(
      onRegistered: () => registered++,
      register: (_) {
        writes++;
        return pending.future;
      },
    ));
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(writes, 1);
    expect(tester.widget<TextField>(field('Email')).enabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pump();
    expect(registered, 0);
    expect(tester.takeException(), isNull);
  });
}
