import 'package:caresitter_customer/core/widgets/notification_bell_button.dart';
import 'package:flutter/material.dart';

class HomeNotificationButton extends StatelessWidget {
  const HomeNotificationButton(
      {super.key, required this.callbackAction2, required this.unreadCount});
  final void Function() callbackAction2;
  final int unreadCount;

  @override
  Widget build(BuildContext context) => NotificationBellButton(
        unreadCount: unreadCount,
        onPressed: callbackAction2,
      );
}
