import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ProfileEditAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ProfileEditAppBar(
      {super.key,
      required this.requestExit,
      required this.busy,
      required this.onSave});
  final void Function() requestExit;
  final bool busy;
  final VoidCallback onSave;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Thông tin cá nhân'),
        leading: AppBackButton(
          fallbackRoute: AppRoutes.settings,
          onPressed: requestExit,
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : onSave,
            child: const Text(
              'Lưu',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: AppFontSizes.s16,
              ),
            ),
          ),
        ],
      );
}
