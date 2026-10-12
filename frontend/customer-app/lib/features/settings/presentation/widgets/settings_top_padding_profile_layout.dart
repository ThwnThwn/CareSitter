import 'package:caresitter_customer/features/settings/presentation/widgets/settings_top_padding_profile_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class SettingsTopPaddingProfileLayout extends StatelessWidget {
  const SettingsTopPaddingProfileLayout(
      {super.key,
      required this.buildFlatHeader,
      required this.ref,
      required this.topPadding,
      required this.buildProfileCard,
      required this.profile,
      required this.bookings,
      required this.totalSpent,
      required this.buildBeneficiariesSection,
      required this.buildSection,
      required this.buildLogoutButton});
  final Widget Function(BuildContext, WidgetRef, double) buildFlatHeader;
  final WidgetRef ref;
  final double topPadding;
  final Widget Function(BuildContext, WidgetRef, UserProfile, int, double)
      buildProfileCard;
  final UserProfile profile;
  final List<BookingModel> bookings;
  final double totalSpent;
  final Widget Function(BuildContext, WidgetRef) buildBeneficiariesSection;
  final Widget Function(String, List<Widget>) buildSection;
  final Widget Function(BuildContext, WidgetRef) buildLogoutButton;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SettingsTopPaddingProfileContent(
            buildFlatHeader: buildFlatHeader,
            ref: ref,
            topPadding: topPadding,
            buildProfileCard: buildProfileCard,
            profile: profile,
            bookings: bookings,
            totalSpent: totalSpent,
            buildBeneficiariesSection: buildBeneficiariesSection,
            buildSection: buildSection,
            buildLogoutButton: buildLogoutButton,
            callbackAction1: () => context.push('/settings/recovery-email'),
            callbackAction2: () => context.push('/settings/password'),
            callbackAction3: () => context.push('/settings/faq'),
            callbackAction4: () => context.push('/settings/support'),
            callbackAction5: () => showLicensePage(
                context: context, applicationName: 'CareSitter')),
      );
}
