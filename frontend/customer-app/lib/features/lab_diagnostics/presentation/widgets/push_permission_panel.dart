import 'package:caresitter_customer/core/push/push_permission_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/lab_fcm_token_controller.dart';

class PushPermissionPanel extends ConsumerStatefulWidget {
  const PushPermissionPanel({super.key});

  @override
  ConsumerState<PushPermissionPanel> createState() =>
      _PushPermissionPanelState();
}

class _PushPermissionPanelState extends ConsumerState<PushPermissionPanel> {
  bool _copying = false;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () => ref.read(pushPermissionActionProvider)(),
            child: const Text('Kiểm tra quyền và đăng ký thông báo'),
          ),
          if (LabFcmTokenController.enabled)
            OutlinedButton.icon(
              onPressed: _copying ? null : _copyToken,
              icon: const Icon(Icons.copy_outlined),
              label: Text(_copying ? 'Đang lấy token…' : 'Sao chép FCM token'),
            ),
        ],
      );

  Future<void> _copyToken() async {
    setState(() => _copying = true);
    var message = 'Chưa lấy được FCM token. Kiểm tra mạng rồi thử lại.';
    try {
      final token = await ref.read(labFcmTokenControllerProvider).readAsync();
      if (!mounted) return;
      if (token != null) {
        await Clipboard.setData(ClipboardData(text: token));
        message = 'Đã sao chép FCM token.';
      }
    } on Exception {
      // Keep the Firebase error and device token out of logs and UI messages.
    } finally {
      if (mounted) {
        setState(() => _copying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }
}
