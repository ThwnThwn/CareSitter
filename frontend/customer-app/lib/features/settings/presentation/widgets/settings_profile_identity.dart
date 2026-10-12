import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class SettingsProfileIdentity extends StatelessWidget {
  const SettingsProfileIdentity(
      {super.key,
      required this.hasAvatar,
      required this.profile,
      required this.initials,
      required this.callbackAction1});
  final bool hasAvatar;
  final UserProfile profile;
  final String initials;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Stack(children: [
        CircleAvatar(
          radius: 46,
          backgroundColor: AppColors.primaryContainer,
          backgroundImage: hasAvatar
              ? NetworkImage(profile.avatarUrl!) as ImageProvider
              : null,
          child: hasAvatar
              ? null
              : Text(initials.isNotEmpty ? initials : 'U',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.s20,
                      fontWeight: FontWeight.w800)),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: callbackAction1,
            child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 14)),
          ),
        ),
      ]);
}
