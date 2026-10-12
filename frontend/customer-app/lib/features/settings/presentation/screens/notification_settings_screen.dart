import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/notification_preferences_controller.dart';
import '../widgets/notification_settings_prefs_toggle_list.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final controller = ref.read(notificationPrefsProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cài đặt thông báo')),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Không tải được cài đặt.'),
            TextButton(
              onPressed: () => ref.invalidate(notificationPrefsProvider),
              child: const Text('Thử lại'),
            ),
          ]),
        ),
        data: (value) => Column(children: [
          if (value.saving) const LinearProgressIndicator(),
          if (value.saveError)
            MaterialBanner(
              content: const Text('Chưa lưu được thay đổi. Vui lòng thử lại.'),
              actions: [
                TextButton(
                    onPressed: controller.retrySave, child: const Text('Lưu lại')),
              ],
            ),
          Expanded(
              child: NotificationSettingsPrefsToggleList(
                  prefs: value.preferences, onChanged: controller.toggle)),
        ]),
      ),
    );
  }
}
