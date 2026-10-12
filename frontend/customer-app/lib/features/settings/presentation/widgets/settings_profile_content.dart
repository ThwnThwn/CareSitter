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
      required this.formatCurrency,
      required this.totalSpent,
      required this.callbackAction1,
      required this.callbackAction2});
  final bool hasAvatar;
  final UserProfile profile;
  final String initials;
  final int bookingCount;
  final String Function(double) formatCurrency;
  final double totalSpent;
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SettingsProfileIdentity(
              hasAvatar: hasAvatar,
              profile: profile,
              initials: initials,
              callbackAction1: callbackAction1),
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
              bookingCount: bookingCount,
              formatCurrency: formatCurrency,
              totalSpent: totalSpent),
          const SizedBox(height: AppSpacing.md),
          SettingsProfileEditLink(callbackAction2: callbackAction2),
        ],
      );
}
