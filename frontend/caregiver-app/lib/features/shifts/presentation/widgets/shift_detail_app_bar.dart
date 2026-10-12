import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';

class ShiftDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShiftDetailAppBar({super.key, required this.callbackAction1});
  final void Function() callbackAction1;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.border,
        title: const Text(
          'Chi tiết Ca',
          style: TextStyle(
              fontSize: AppFontSizes.s18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        leading: const AppBackButton(fallbackRoute: '/shifts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            onPressed: callbackAction1,
          ),
        ],
      );
}
