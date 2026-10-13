import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RegisterScreenLoginLink extends StatelessWidget {
  const RegisterScreenLoginLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Đã có tài khoản?',
          style:
              TextStyle(color: AppColors.textSecondary, fontSize: AppFontSizes.s14),
        ),
        TextButton(
          onPressed: () => context.pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tight),
            minimumSize: Size.zero,
          ),
          child: const Text(
            'Đăng nhập',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
