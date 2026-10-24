import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SettingsProfileHeader extends StatelessWidget {
  const SettingsProfileHeader({
    super.key,
    required this.topPadding,
    required this.onEditProfile,
  });

  final double topPadding;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.cardBackground,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.section,
          topPadding + AppSpacing.md,
          AppSpacing.md,
          AppSpacing.inset,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hồ sơ của tôi',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFontSizes.s22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: AppSpacing.micro),
                  Text(
                    'Tài khoản & công việc CareSitter',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSizes.s12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEditProfile,
              tooltip: 'Chỉnh sửa hồ sơ',
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
