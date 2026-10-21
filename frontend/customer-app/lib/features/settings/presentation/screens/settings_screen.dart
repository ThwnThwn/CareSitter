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

/// Màn hình Cài đặt & Hồ sơ của tôi — thiết kế chuẩn theo Stitch "Hồ sơ của tôi - CareSitter Redesign".
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SettingsFlatHeader(
              topPadding: MediaQuery.paddingOf(context).top,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              100,
            ),
            sliver: SliverList.list(
              children: [
                // 1. Profile Hero Card
                FadeSlideStaggered(
                  index: 0,
                  child: SettingsProfileCard(
                    profile: profile,
                    bookingCount: bookings.length,
                    totalSpent: totalSpent,
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Người thân được chăm sóc
                const FadeSlideStaggered(
                  index: 1,
                  child: SettingsBeneficiariesSection(),
                ),
                const SizedBox(height: 18),

                // 3. Tài khoản
                const SettingsAccountSection(),
                const SizedBox(height: 18),

                // 4. Bảo mật
                const FadeSlideStaggered(
                  index: 3,
                  child: SettingsSecuritySection(),
                ),
                const SizedBox(height: 18),

                // 5. Hỗ trợ & Điều khoản & Đăng xuất
                const FadeSlideStaggered(
                  index: 4,
                  child: SettingsSupportSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
