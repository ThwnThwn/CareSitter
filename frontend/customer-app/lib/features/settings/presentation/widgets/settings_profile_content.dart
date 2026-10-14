import 'package:caresitter_customer/features/settings/presentation/widgets/settings_profile_identity.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_profile_edit_link.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_booking_stats.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class SettingsProfileContent extends StatelessWidget {
  const SettingsProfileContent(
      {super.key,
      required this.hasAvatar,
      required this.profile,
      required this.initials,
      required this.bookingCount,
      required this.totalSpent,
      required this.onEditProfile});
  final bool hasAvatar;
  final UserProfile profile;
  final String initials;
  final int bookingCount;
  final double totalSpent;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SettingsProfileIdentity(
              hasAvatar: hasAvatar,
              profile: profile,
              initials: initials,
              onEditProfile: onEditProfile),
          const SizedBox(height: AppSpacing.compact),
          Text(profile.name.isNotEmpty ? profile.name : 'Người dùng',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.s18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text(
              [
                if (profile.phone.isNotEmpty) profile.phone,
                if (profile.email.isNotEmpty) profile.email
              ].join(' - '),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s12),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.compact),
          SettingsBookingStats(
              bookingCount: bookingCount, totalSpent: totalSpent),
          const SizedBox(height: AppSpacing.md),
          SettingsProfileEditLink(onEditProfile: onEditProfile),
        ],
      );
}
