import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';

class ProfileEditAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ProfileEditAppBar(
      {super.key, required this.isSaving, required this.saveProfile});
  final bool isSaving;
  final Future<void> Function() saveProfile;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Thông tin cá nhân'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
        actions: [
          TextButton(
            onPressed: isSaving ? null : saveProfile,
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSizes.s16,
                    ),
                  ),
          ),
        ],
      );
}
