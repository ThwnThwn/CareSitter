import 'package:caresitter_customer/features/settings/presentation/widgets/settings_profile_content.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard(
      {super.key,
      required this.profile,
      required this.bookingCount,
      required this.totalSpent});
  final UserProfile profile;
  final int bookingCount;
  final double totalSpent;
  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;
    final initials = profile.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .map((String p) => p[0].toUpperCase())
        .take(2)
        .join();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.section),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card),
      child: SettingsProfileContent(
          hasAvatar: hasAvatar,
          profile: profile,
          initials: initials,
          bookingCount: bookingCount,
          totalSpent: totalSpent,
          onEditProfile: () => context.push('/settings/profile/edit')),
    );
  }
}
