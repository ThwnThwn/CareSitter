import 'package:caregiver_app/features/home/presentation/widgets/home_avatar.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_greeting.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_notification_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';

class HomeStickyHeader extends ConsumerWidget {
  const HomeStickyHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).value;
    final profile = ref.watch(profileProvider);
    final displayName =
        profile.name.trim().isNotEmpty && profile.name != 'Caregiver'
            ? profile.name.trim()
            : (auth?.phone?.trim().isNotEmpty ?? false)
                ? auth!.phone!.trim()
                : 'Caregiver';
    final greetingName = _shortName(displayName);

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
          HomeAvatar(profile: profile),
          const SizedBox(width: AppSpacing.compact),
          // Name + status toggle
          HomeGreeting(greetingName: greetingName, profile: profile),
        ],
      ),
      actions: const [
        // Notification bell với badge động
        HomeNotificationButton(),
        SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  String _shortName(String displayName) {
    final parts =
        displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.isEmpty ? 'Caregiver' : parts.last;
  }
}
