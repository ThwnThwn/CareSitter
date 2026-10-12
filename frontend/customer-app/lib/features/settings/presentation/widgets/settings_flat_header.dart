import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsFlatHeader extends StatelessWidget {
  const SettingsFlatHeader({super.key, required this.topPadding});
  final double topPadding;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
          top: topPadding + 16,
          left: AppSpacing.section,
          right: AppSpacing.md,
          bottom: AppSpacing.inset),
      child: Row(
        children: [
          const Expanded(
              child: Text('Hồ sơ của tôi',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFontSizes.s22,
                      fontWeight: FontWeight.w800))),
          GestureDetector(
            onTap: () => context.push('/settings/profile/edit'),
            child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: AppColors.background, shape: BoxShape.circle),
                child: const Icon(Icons.settings_outlined,
                    color: AppColors.textSecondary, size: 22)),
          ),
        ],
      ),
    );
  }
}
