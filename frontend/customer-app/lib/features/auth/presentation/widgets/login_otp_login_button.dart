import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';

class LoginOtpLoginButton extends StatelessWidget {
  const LoginOtpLoginButton({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: enabled ? () => context.push(AppRoutes.email) : null,
        icon: const Icon(
          Icons.mark_email_read_outlined,
          size: 18,
          color: LoginHeroTokens.primaryDeep,
        ),
        label: const Text(
          'Đăng nhập bằng mã OTP (Email)',
          style: TextStyle(
            fontSize: AppFontSizes.s13,
            fontWeight: FontWeight.w600,
            color: LoginHeroTokens.primaryDeep,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: LoginHeroTokens.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
