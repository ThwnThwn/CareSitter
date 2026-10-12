import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeProfileAvatar extends StatelessWidget {
  const HomeProfileAvatar(
      {super.key,
      required this.callbackAction1,
      required this.avatarImage,
      required this.initials});
  final void Function() callbackAction1;
  final ImageProvider<Object>? avatarImage;
  final String initials;

  @override
  Widget build(BuildContext context) => HomeHoverButton(
        borderRadius: BorderRadius.circular(999),
        onTap: callbackAction1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryContainer,
            backgroundImage: avatarImage,
            child: avatarImage != null
                ? null
                : Text(
                    initials.isNotEmpty ? initials : 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.s14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      );
}
