import 'package:caresitter_customer/features/settings/presentation/widgets/notification_settings_prefs_toggle_list.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/notification_preferences_controller.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cài đặt thông báo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.compact),
              const Text('Không tải được cài đặt.'),
              TextButton(
                onPressed: () => ref.invalidate(notificationPrefsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (prefs) => NotificationSettingsPrefsToggleList(
            buildSectionHeader: _buildSectionHeader,
            buildTile: _buildTile,
            ref: ref,
            prefs: prefs,
            toggle: _toggle),
      ),
    );
  }

  void _toggle(WidgetRef ref, NotificationPrefs updated) {
    ref.read(notificationPrefsProvider.notifier).toggle(updated);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.section, AppSpacing.md, AppSpacing.xs),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: AppFontSizes.s12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
    NotificationPrefs prefs, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: value ? AppColors.primaryContainer : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.compact),
        ),
        child: Icon(icon,
            size: 20,
            color: value ? AppColors.primary : AppColors.textSecondary),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: AppFontSizes.s14,
              color: AppColors.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: AppFontSizes.s12, color: AppColors.textSecondary)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
    );
  }
}
