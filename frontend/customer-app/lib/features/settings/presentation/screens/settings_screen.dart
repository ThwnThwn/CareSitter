import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/settings_flat_header.dart';
import '../widgets/settings_profile_card.dart';
import '../widgets/settings_beneficiaries_section.dart';
import '../widgets/settings_account_section.dart';
import '../widgets/settings_security_section.dart';
import '../widgets/settings_support_section.dart';
import '../widgets/settings_logout_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileStoreProvider);
    final bookings = ref.watch(bookingStoreProvider);
    final totalSpent = bookings
        .where((b) => b.status == 'completed')
        .fold(0.0, (sum, b) => sum + b.totalPrice);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child:
              SettingsFlatHeader(topPadding: MediaQuery.paddingOf(context).top),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
          sliver: SliverList.list(children: [
            FadeSlideStaggered(
                index: 0,
                child: SettingsProfileCard(
                    profile: profile,
                    bookingCount: bookings.length,
                    totalSpent: totalSpent)),
            const SizedBox(height: AppSpacing.section),
            const FadeSlideStaggered(
                index: 1, child: SettingsBeneficiariesSection()),
            const SizedBox(height: AppSpacing.section),
            const SettingsAccountSection(),
            const SizedBox(height: AppSpacing.md),
            const FadeSlideStaggered(
                index: 3, child: SettingsSecuritySection()),
            const SizedBox(height: AppSpacing.md),
            const FadeSlideStaggered(index: 4, child: SettingsSupportSection()),
            const SizedBox(height: AppSpacing.lg),
            const FadeSlideStaggered(index: 5, child: SettingsLogoutButton()),
            const SizedBox(height: AppSpacing.xl),
          ]),
        ),
      ]),
    );
  }
}
