import 'package:caregiver_app/features/home/presentation/widgets/home_avatar.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_greeting.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_notification_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';

class HomeStickyHeader extends StatelessWidget {
  const HomeStickyHeader(
      {super.key,
      required this.ref,
      required this.shortName,
      required this.initials});
  final WidgetRef ref;
  final String Function(String) shortName;
  final String Function(String) initials;
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider).value;
    final profile = ref.watch(profileProvider);
    final displayName =
        profile.name.trim().isNotEmpty && profile.name != 'Caregiver'
            ? profile.name.trim()
            : (auth?.phone?.trim().isNotEmpty ?? false)
                ? auth!.phone!.trim()
                : 'Caregiver';
    final greetingName = shortName(displayName);
    final initials = this.initials(displayName);

    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.shadow,
      toolbarHeight: 68,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Avatar + online dot
          HomeAvatar(initials: initials),
          const SizedBox(width: AppSpacing.compact),
          // Name + status toggle
          HomeGreeting(greetingName: greetingName, profile: profile),
        ],
      ),
      actions: [
        // Notification bell với badge động
        HomeNotificationButton(
            ref: ref,
            callbackAction1: (n) => !n.isRead,
            callbackAction2: () => context.push('/notifications')),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
