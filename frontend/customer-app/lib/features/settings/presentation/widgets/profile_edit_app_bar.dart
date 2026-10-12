import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_edit_controller.dart';

class ProfileEditAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ProfileEditAppBar(
      {super.key,
      required this.requestExit,
      required this.ref,
      required this.isUploadingAvatar,
      required this.saveProfile});
  final void Function() requestExit;
  final WidgetRef ref;
  final bool isUploadingAvatar;
  final Future<void> Function() saveProfile;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Thông tin cá nhân'),
        leading: AppBackButton(
          fallbackRoute: '/settings',
          onPressed: requestExit,
        ),
        actions: [
          TextButton(
            onPressed: (ref.watch(profileEditControllerProvider).busy ||
                    isUploadingAvatar)
                ? null
                : saveProfile,
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
