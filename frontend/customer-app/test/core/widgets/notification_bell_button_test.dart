import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/notification_bell_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the shared unread indicator and invokes its action',
      (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: NotificationBellButton(
            unreadCount: 3,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(
      find.byKey(const Key('notification-unread-indicator')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Thông báo, 3 thông báo chưa đọc'),
        findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    expect(pressed, isTrue);
  });

  testWidgets('hides the unread indicator when the inbox is clear',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: NotificationBellButton(
            unreadCount: 0,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('notification-unread-indicator')),
      findsNothing,
    );
    expect(find.bySemanticsLabel('Thông báo'), findsOneWidget);
  });
}
