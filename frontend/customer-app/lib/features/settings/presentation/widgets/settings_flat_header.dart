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
      color: AppColors.surface,
      padding: EdgeInsets.only(
          top: topPadding + 16,
          left: AppSpacing.section,
          right: AppSpacing.md,
          bottom: AppSpacing.inset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hồ sơ của tôi',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppFontSizes.s22,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Tài khoản & dịch vụ CareSitter',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppFontSizes.s12)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: () => context.push('/settings/profile/edit'),
            tooltip: 'Cài đặt hồ sơ',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.settings_outlined, size: 22),
          ),
        ],
      ),
    );
  }
}
