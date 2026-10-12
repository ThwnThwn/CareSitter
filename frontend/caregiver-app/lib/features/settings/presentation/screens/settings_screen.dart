import 'package:caregiver_app/features/settings/presentation/widgets/settings_profile_links.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_support_links.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_logout_action.dart';
import 'package:caregiver_app/features/settings/presentation/models/settings_item.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_profile_card.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/login_controller.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tài khoản'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _buildProfileCard(context, profile),
            const SizedBox(height: AppSpacing.xl),
            SettingsProfileLinks(
                buildSection: _buildSection,
                callbackAction1: () => context.push('/settings/recovery-email'),
                callbackAction2: () => context.push('/settings/profile/edit'),
                callbackAction3: () => context.push('/earnings'),
                callbackAction4: () => context.push('/settings/documents'),
                callbackAction5: () => context.push('/settings/reviews')),
            const SizedBox(height: AppSpacing.lg),
            SettingsSupportLinks(
                buildSection: _buildSection,
                callbackAction1: () => context.push('/settings/faq'),
                callbackAction2: () => context.push('/settings/support')),
            const SizedBox(height: AppSpacing.xl),
            SettingsLogoutAction(callbackAction1: () async {
              await ref.read(loginControllerProvider).logout();
              if (context.mounted) context.go('/auth/phone');
            }),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'CareSitter Caregiver v1.0.0',
              style: TextStyle(
                  fontSize: AppFontSizes.s12, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(
          BuildContext context, CaregiverProfileModel profile) =>
      SettingsProfileCard(profile: profile, shortIdLabel: _shortIdLabel);

  String _shortIdLabel(String id) {
    if (id.isEmpty) return 'Chưa có hồ sơ caregiver';
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    return 'ID hồ sơ: $shortId';
  }

  Widget _buildSection(
          {required String title, required List<SettingsItem> items}) =>
      SettingsSection(title: title, items: items);
}
