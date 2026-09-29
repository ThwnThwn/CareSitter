import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/email_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('email OTP screen supports 320 px and enlarged text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
            ),
            child: child!,
          ),
          home: const EmailInputScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập với OTP'), findsOneWidget);
    expect(find.text('Gửi mã OTP qua Email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
