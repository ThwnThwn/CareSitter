import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_messenger.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/core/widgets/toast_message_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('legacy action toast stays visible after navigation',
      (tester) async {
    late BuildContext pageContext;
    var actionInvoked = false;
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: appMessengerKey,
      home: Scaffold(body: Builder(builder: (context) {
        pageContext = context;
        return const SizedBox.shrink();
      })),
    ));

    AppToast.showLegacy(
      pageContext,
      SnackBar(
        content: const Text('Chọn lại caregiver'),
        backgroundColor: AppColors.error,
        action: SnackBarAction(
          label: 'Chọn lại',
          onPressed: () => actionInvoked = true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Chọn lại caregiver'), findsOneWidget);
    expect(
        tester
            .widget<ToastMessageContent>(find.byType(ToastMessageContent))
            .type,
        AppToastType.error);

    Navigator.of(pageContext).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Chi tiết lịch')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Chi tiết lịch'), findsOneWidget);
    expect(find.text('Chọn lại caregiver'), findsOneWidget);

    await tester.tap(find.text('Chọn lại'));
    await tester.pump();
    expect(actionInvoked, isTrue);
    expect(find.byType(ToastMessageContent), findsNothing);
  });

  testWidgets('toast timer is cancelled when app is disposed', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        pageContext = context;
        return const Scaffold();
      }),
    ));
    AppToast.info(pageContext, 'Đang kiểm tra lịch');
    await tester.pump();
    expect(find.byType(ToastMessageContent), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(find.byType(ToastMessageContent), findsNothing);
  });

  testWidgets('regular toasts disappear after three seconds', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        pageContext = context;
        return const Scaffold();
      }),
    ));
    final showToast = <void Function()>[
      () => AppToast.info(pageContext, 'Thông tin'),
      () => AppToast.success(pageContext, 'Đã lưu'),
      () => AppToast.error(pageContext, 'Có lỗi'),
      () => AppToast.showLegacy(
          pageContext, const SnackBar(content: Text('Thông báo cũ'))),
    ];
    for (final show in showToast) {
      show();
      await tester.pump();
      expect(find.byType(ToastMessageContent), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.byType(ToastMessageContent), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.byType(ToastMessageContent), findsNothing);
    }
  });
}
