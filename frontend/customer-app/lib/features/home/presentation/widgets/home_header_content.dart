import 'package:caresitter_customer/features/home/presentation/widgets/home_notification_button.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_greeting.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class HomeHeaderContent extends StatelessWidget {
  const HomeHeaderContent(
      {super.key,
      required this.profile,
      required this.unreadCount,
      required this.callbackAction1,
      required this.callbackAction2});
  final UserProfile profile;
  final int unreadCount;
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ──
          HomeProfileAvatar(callbackAction1: callbackAction1, profile: profile),
          const SizedBox(width: AppSpacing.compact),

          // ── App Branding ──
          HomeGreeting(profile: profile),

          // ── Notification Bell ──
          HomeNotificationButton(
              callbackAction2: callbackAction2, unreadCount: unreadCount),
        ],
      );
}
