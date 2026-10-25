import 'package:caresitter_customer/features/home/presentation/widgets/home_header_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader(
      {super.key,
      required this.profile,
      required this.topPadding,
      required this.unreadCount});
  final UserProfile profile;
  final double topPadding;
  final int unreadCount;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: topPadding + 14,
        left: AppSpacing.comfortable,
        right: AppSpacing.comfortable,
        bottom: AppSpacing.inset,
      ),
      child: HomeHeaderContent(
          profile: profile,
          unreadCount: unreadCount,
          callbackAction1: () => context.push(AppRoutes.settings),
          callbackAction2: () => context.push(AppRoutes.notifications)),
    );
  }
}
