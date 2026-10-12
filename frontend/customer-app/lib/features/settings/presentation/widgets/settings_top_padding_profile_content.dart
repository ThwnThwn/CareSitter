import 'package:caresitter_customer/features/settings/presentation/widgets/settings_profile_bookings_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class SettingsTopPaddingProfileContent extends StatelessWidget {
  const SettingsTopPaddingProfileContent(
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
      required this.buildLogoutButton,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5});
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
  final void Function() callbackAction1;
  final void Function() callbackAction2;
  final void Function() callbackAction3;
  final void Function() callbackAction4;
  final void Function() callbackAction5;

  @override
  Widget build(BuildContext context) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: buildFlatHeader(context, ref, topPadding),
          ),
          SettingsProfileBookingsContent(
              buildProfileCard: buildProfileCard,
              ref: ref,
              profile: profile,
              bookings: bookings,
              totalSpent: totalSpent,
              buildBeneficiariesSection: buildBeneficiariesSection,
              buildSection: buildSection,
              callbackAction1: callbackAction1,
              callbackAction2: callbackAction2,
              callbackAction3: callbackAction3,
              callbackAction4: callbackAction4,
              callbackAction5: callbackAction5,
              buildLogoutButton: buildLogoutButton),
        ],
      );
}
