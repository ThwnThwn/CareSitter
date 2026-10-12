import 'package:flutter/material.dart';

class NotificationsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const NotificationsAppBar({super.key, required this.callbackAction1});
  final void Function() callbackAction1;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: callbackAction1,
            child: const Text(
              'Đọc tất cả',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}
