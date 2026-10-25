import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_app_bar_title.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_app_bar_menu.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  const ShiftTrackingAppBar({super.key});

  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const ShiftTrackingAppBarTitle(),
        leading: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.border.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
              ],
            ),
            child: const AppBackButton(
              fallbackRoute: AppRoutes.bookings,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        actions: const [
          ShiftTrackingAppBarMenu(),
        ],
      );
}
