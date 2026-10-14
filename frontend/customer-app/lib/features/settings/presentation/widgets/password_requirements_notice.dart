import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class PasswordRequirementsNotice extends StatelessWidget {
  const PasswordRequirementsNotice({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border:
                Border.all(color: AppColors.warning.withValues(alpha: 0.4))),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          SizedBox(width: AppSpacing.control),
          Expanded(
              child: Text(
                  'Mật khẩu mới phải có ít nhất 8 ký tự, bao gồm chữ cái và số.',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontSize: AppFontSizes.s13,
                      height: 1.4))),
        ]),
      );
}
