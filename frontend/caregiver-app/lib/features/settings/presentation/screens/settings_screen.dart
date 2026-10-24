import 'package:caregiver_app/features/settings/presentation/widgets/settings_profile_links.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_support_links.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_logout_action.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_profile_card.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_profile_header.dart';
import 'package:caregiver_app/features/earnings/presentation/controllers/earnings_controller.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/login_controller.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final earnings = ref.watch(earningsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SettingsProfileHeader(
              topPadding: MediaQuery.paddingOf(context).top,
              onEditProfile: () => context.push('/settings/profile/edit'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.s100,
            ),
            sliver: SliverList.list(
              children: [
                SettingsProfileCard(
                  profile: profile,
                  completedShifts: earnings.completedShifts,
                  monthTotal: earnings.monthTotal,
                  onEditProfile: () => context.push('/settings/profile/edit'),
                ),
                const SizedBox(height: AppSpacing.comfortable),
                const SettingsProfileLinks(),
                const SizedBox(height: AppSpacing.comfortable),
                const SettingsSupportLinks(),
                const SizedBox(height: AppSpacing.xl),
                SettingsLogoutAction(onLogout: () async {
                  await ref.read(loginControllerProvider).logout();
                  if (context.mounted) context.go('/auth/phone');
                }),
                const SizedBox(height: AppSpacing.xl),
                const Center(
                  child: Text(
                    'CareSitter Caregiver v1.0.0',
                    style: TextStyle(
                      fontSize: AppFontSizes.s12,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
