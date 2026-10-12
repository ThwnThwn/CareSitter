import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RegisterScreenTitle extends StatelessWidget {
  const RegisterScreenTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tạo tài khoản',
            style: TextStyle(
              fontSize: AppFontSizes.s26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: AppSpacing.tight),
          Text(
            'Điền thông tin để bắt đầu chăm sóc người thân',
            style: TextStyle(
              fontSize: AppFontSizes.s14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
