import 'package:caresitter_customer/features/settings/presentation/widgets/settings_content.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_settings_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class SettingsProfileBookingsContent extends StatelessWidget {
  const SettingsProfileBookingsContent(
      {super.key,
      required this.buildProfileCard,
      required this.ref,
      required this.profile,
      required this.bookings,
      required this.totalSpent,
      required this.buildBeneficiariesSection,
      required this.buildSection,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5,
      required this.buildLogoutButton});
  final Widget Function(BuildContext, WidgetRef, UserProfile, int, double)
      buildProfileCard;
  final WidgetRef ref;
  final UserProfile profile;
  final List<BookingModel> bookings;
  final double totalSpent;
  final Widget Function(BuildContext, WidgetRef) buildBeneficiariesSection;
  final Widget Function(String, List<Widget>) buildSection;
  final void Function() callbackAction1;
  final void Function() callbackAction2;
  final void Function() callbackAction3;
  final void Function() callbackAction4;
  final void Function() callbackAction5;
  final Widget Function(BuildContext, WidgetRef) buildLogoutButton;

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            // Profile card
            FadeSlideStaggered(
              index: 0,
              child: buildProfileCard(
                  context, ref, profile, bookings.length, totalSpent),
            ),
            const SizedBox(height: AppSpacing.section),

            // Beneficiaries section
            FadeSlideStaggered(
              index: 1,
              child: buildBeneficiariesSection(context, ref),
            ),
            const SizedBox(height: AppSpacing.section),

            // Settings
            SettingsContent(buildSection: buildSection),
            const SizedBox(height: AppSpacing.md),
            FadeSlideStaggered(
              index: 3,
              child: buildSection('Bảo mật', [
                SettingsSettingsItem(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Email khôi phục',
                  subtitle: 'Xác minh hoặc đổi email đăng nhập',
                  onTap: callbackAction1,
                ),
                SettingsSettingsItem(
                  icon: Icons.lock_outline,
                  title: 'Đổi mật khẩu',
                  onTap: callbackAction2,
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
            FadeSlideStaggered(
              index: 4,
              child: buildSection('Hỗ trợ', [
                SettingsSettingsItem(
                  icon: Icons.help_outline,
                  title: 'Câu hỏi thường gặp',
                  onTap: callbackAction3,
                ),
                SettingsSettingsItem(
                  icon: Icons.headset_mic_outlined,
                  title: 'Liên hệ hỗ trợ',
                  subtitle: 'Hotline: 1800 6789',
                  onTap: callbackAction4,
                ),
                SettingsSettingsItem(
                  icon: Icons.info_outline,
                  title: 'Giấy phép nguồn mở',
                  onTap: callbackAction5,
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Logout button
            FadeSlideStaggered(
              index: 5,
              child: buildLogoutButton(context, ref),
            ),
            const SizedBox(height: AppSpacing.xl),
          ]),
        ),
      );
}
