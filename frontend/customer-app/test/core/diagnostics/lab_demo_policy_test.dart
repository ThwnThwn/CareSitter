import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_support_section.dart';

void main() {
  testWidgets('settings hides lab diagnostics and retains support actions',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: SettingsSupportSection(),
      ))),
    ));
    expect(find.text('Kiểm chứng Lab3'), findsNothing);
    expect(find.text('Liên hệ hỗ trợ'), findsOneWidget);
    expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
  });
}
