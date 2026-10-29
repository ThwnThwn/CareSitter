import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/support_chat/data/support_chat_repository.dart';
import 'package:caregiver_app/features/support_chat/presentation/support_chat_controller.dart';
import 'package:caregiver_app/features/support_chat/presentation/widgets/support_chat_content.dart';
import 'package:caregiver_app/features/support_chat/presentation/widgets/support_chat_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'composer stays visible while history scrolls and only sends text',
      (tester) async {
    final fixture = _ChatFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    final input = find.byKey(const ValueKey('support-message-input'));
    final send = find.widgetWithIcon(IconButton, Icons.send_rounded);
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    final before = tester.getRect(input);

    await tester.drag(find.byKey(const ValueKey('support-message-list')),
        const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getRect(input), before);

    await tester.enterText(input, 'Xin hỗ trợ lịch hẹn');
    await tester.pump();
    await tester.tap(send);
    expect(fixture.sent, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long messages fit a narrow screen with enlarged text',
      (tester) async {
    final fixture = _ChatFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester,
        size: const Size(320, 640), textScale: 2, count: 3);
    expect(find.byKey(const ValueKey('support-message-input')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tin nhắn của CareSitter.*Tin 1:')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const ValueKey('support-message-input')),
        'Một tin nhắn mới');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed history is read only and can open a new request',
      (tester) async {
    final fixture = _ChatFixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester, closed: true, count: 2);
    expect(find.byKey(const ValueKey('support-message-input')), findsNothing);
    await tester.tap(find.text('Gửi yêu cầu mới'));
    await tester.pumpAndSettle();
    expect(find.text('Chủ đề cần hỗ trợ'), findsOneWidget);
    expect(find.text('Nội dung yêu cầu'), findsOneWidget);
    expect(find.text('Quay lại hội thoại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending send keeps the draft and disables repeat submission',
      (tester) async {
    final fixture = _ChatFixture();
    addTearDown(fixture.dispose);
    fixture.draft.text = 'Nội dung đang gửi';
    await fixture.pump(tester, busy: true, count: 2);
    expect(fixture.draft.text, 'Nội dung đang gửi');
    final send = find.byWidgetPredicate((widget) =>
        widget is IconButton && widget.tooltip == 'Đang gửi tin nhắn');
    final button = tester.widget<IconButton>(send);
    expect(button.onPressed, isNull);
    expect(fixture.sent, 0);
    expect(tester.takeException(), isNull);
  });
}

class _ChatFixture {
  final subject = TextEditingController();
  final first = TextEditingController();
  final draft = TextEditingController();
  final scroll = ScrollController();
  int sent = 0;

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(800, 700),
      double textScale = 1,
      bool closed = false,
      bool busy = false,
      int count = 40}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messages = [
      for (var i = 1; i <= count; i++)
        SupportMessage(
            id: 'message-$i',
            sequence: i,
            senderRole: i.isEven ? 'CUSTOMER' : 'ADMIN',
            body: 'Tin $i: Nội dung trao đổi cần được xuống dòng đầy đủ, '
                'để người dùng đọc lại lịch hẹn và nhận hỗ trợ từ CareSitter.',
            createdAt: DateTime.utc(2026, 10, 28, 10, i)),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
            size: size, textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          appBar: SupportChatHeader(
            leading: IconButton(
                onPressed: () {}, icon: const Icon(Icons.arrow_back)),
            status: closed ? 'Hội thoại đã kết thúc' : 'Đang xử lý yêu cầu',
            toolbarHeight: 76 * textScale.clamp(1, 1.6),
            onRefresh: () {},
            onInfo: () {},
          ),
          body: SupportChatContent(
            state: SupportChatState(
              enabled: true,
              loading: false,
              busy: busy,
              conversation: SupportConversation(
                  id: 'conversation',
                  subject: 'Hỗ trợ lịch hẹn của gia đình',
                  status: closed ? 'CLOSED' : 'IN_PROGRESS',
                  lastSequence: count,
                  ownLastReadSequence: 0),
              messages: messages,
            ),
            scrollController: scroll,
            subjectController: subject,
            firstMessageController: first,
            draftController: draft,
            onRefresh: () {},
            onSend: () => sent++,
            onCreate: () {},
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  void dispose() {
    subject.dispose();
    first.dispose();
    draft.dispose();
    scroll.dispose();
  }
}
