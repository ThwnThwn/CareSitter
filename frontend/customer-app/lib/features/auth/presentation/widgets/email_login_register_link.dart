import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class EmailLoginRegisterLink extends StatelessWidget {
  const EmailLoginRegisterLink({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Chưa có tài khoản?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s14,
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.register),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tight),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Đăng ký ngay',
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
