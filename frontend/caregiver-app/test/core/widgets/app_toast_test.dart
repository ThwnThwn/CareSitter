import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/core/widgets/toast_message_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'three toast states provide a title, message, and dismiss control',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Chi tiết ca')),
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    AppToast.info(
      pageContext,
      'Đang lấy vị trí GPS để check-in. Vui lòng giữ ứng dụng mở.',
      title: 'Đang xác thực vị trí',
    );
    await tester.pump();
    expect(find.text('Đang xác thực vị trí'), findsOneWidget);
    expect(find.textContaining('Đang lấy vị trí GPS'), findsOneWidget);
    expect(find.byTooltip('Đóng'), findsOneWidget);
    expect(
      tester.widget<ToastMessageContent>(find.byType(ToastMessageContent)).type,
      AppToastType.info,
    );
    expect(tester.takeException(), isNull);

    AppToast.error(
      pageContext,
      'Độ chính xác GPS phải nằm trong khoảng 15 mét để thực hiện check-in. Vui lòng di chuyển đến nơi có tín hiệu tốt hơn.',
      title: 'Check-in chưa thành công',
    );
    await tester.pump();
    expect(find.text('Check-in chưa thành công'), findsOneWidget);
    expect(find.textContaining('Độ chính xác GPS phải nằm trong khoảng'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<ToastMessageContent>(find.byType(ToastMessageContent)).type,
      AppToastType.error,
    );

    AppToast.success(pageContext, 'Check-in thành công');
    await tester.pump();
    expect(find.text('Check-in thành công'), findsOneWidget);
    expect(
        find.text('Bạn có thể bắt đầu thực hiện ca chăm sóc.'), findsNothing);
    expect(
      tester.widget<ToastMessageContent>(find.byType(ToastMessageContent)).type,
      AppToastType.success,
    );

    AppToast.dismiss(pageContext);
  });

  testWidgets('toast stays below the app bar', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Chi tiết Ca')),
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    AppToast.error(pageContext, 'Không thể check-in');
    await tester.pump();

    final positioned = tester.widget<Positioned>(
      find.ancestor(
        of: find.byType(ToastMessageContent),
        matching: find.byType(Positioned),
      ),
    );
    expect(positioned.top, kToolbarHeight + 12);

    AppToast.dismiss(pageContext);
  });

  testWidgets('action toast invokes its callback and dismisses itself',
      (tester) async {
    late BuildContext pageContext;
    var actionInvoked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    AppToast.info(
      pageContext,
      'Bạn có một thông báo mới.',
      title: 'Ca làm việc vừa cập nhật',
      actionLabel: 'Xem',
      onAction: () => actionInvoked = true,
    );
    await tester.pump();

    expect(find.text('Xem'), findsOneWidget);
    await tester.tap(find.text('Xem'));
    await tester.pump();

    expect(actionInvoked, isTrue);
    expect(find.byType(ToastMessageContent), findsNothing);
  });

  testWidgets('information toast closes after four seconds', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        pageContext = context;
        return const Scaffold();
      }),
    ));

    AppToast.info(pageContext, 'Bạn có 1 tin nhắn mới');
    await tester.pump();
    expect(find.byType(ToastMessageContent), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(ToastMessageContent), findsNothing);
  });
}
