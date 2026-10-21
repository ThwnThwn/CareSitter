import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/screens/login_screen.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/auth_hero_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLogin(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(320, 568),
    Size(430, 932),
    Size(1024, 768),
  ]) {
    testWidgets('renders without overflow at ${size.width}x${size.height}',
        (tester) async {
      await pumpLogin(tester, size);

      expect(find.text('Chào mừng trở lại!'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps the wide layout split and the form readable',
      (tester) async {
    await pumpLogin(tester, const Size(1024, 768));

    final heroRect = tester.getRect(find.byType(AuthHeroHeader));
    final emailRect = tester.getRect(find.byType(TextFormField).first);

    expect(heroRect.right, lessThan(emailRect.left));
    expect(emailRect.width, lessThanOrEqualTo(AppLayout.authFormMaxWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports larger accessibility text on a compact viewport',
      (tester) async {
    await pumpLogin(
      tester,
      const Size(320, 568),
      textScale: 1.4,
    );

    expect(find.text('Đăng nhập bằng mã OTP (Email)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not show decorative hero badges on mobile', (tester) async {
    await pumpLogin(tester, const Size(430, 932));

    expect(find.text('CareSitter'), findsNothing);
    expect(find.text('10,000+ Gia đình'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delays credential validation until login is submitted',
      (tester) async {
    await pumpLogin(tester, const Size(430, 932));

    await tester.enterText(find.byType(TextFormField).first, 'thuanvct1');
    await tester.pump();

    expect(find.text('Email hoặc số điện thoại không hợp lệ'), findsNothing);
    expect(find.text('Vui lòng nhập mật khẩu'), findsNothing);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pump();

    expect(find.text('Email hoặc số điện thoại không hợp lệ'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);

    await tester.enterText(
        find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'secret1');
    await tester.pump();

    expect(find.text('Email hoặc số điện thoại không hợp lệ'), findsNothing);
    expect(find.text('Vui lòng nhập mật khẩu'), findsNothing);
  });

  testWidgets('aligns auxiliary action and social divider with the form',
      (tester) async {
    await pumpLogin(tester, const Size(430, 932));

    final fieldRect = tester.getRect(find.byType(TextFormField).first);
    final forgotPasswordRect = tester.getRect(find.text('Quên mật khẩu?'));
    final socialDividerRect = tester.getRect(find.text('Hoặc tiếp tục với'));

    expect(forgotPasswordRect.right, closeTo(fieldRect.right, 0.5));
    expect(socialDividerRect.center.dx, closeTo(fieldRect.center.dx, 0.5));
  });
}
