import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';

class LoginRegisterFooter extends StatelessWidget {
  const LoginRegisterFooter({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.comfortable, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: LoginHeroTokens.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Chưa có tài khoản?',
            style: TextStyle(
              fontSize: AppFontSizes.s14,
              color: LoginHeroTokens.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: enabled ? () => context.push(AppRoutes.register) : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tight),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Đăng ký ngay',
              style: TextStyle(
                fontSize: AppFontSizes.s14,
                fontWeight: FontWeight.w700,
                color: LoginHeroTokens.primaryDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
