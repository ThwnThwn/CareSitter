import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';

class LoginWelcomeHeading extends StatelessWidget {
  const LoginWelcomeHeading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chào mừng trở lại!',
          style: TextStyle(
            fontSize: AppFontSizes.s24,
            fontWeight: FontWeight.w700,
            color: LoginHeroTokens.onSurface,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Đăng nhập để chăm sóc người thân yêu tốt hơn mỗi ngày.',
          style: TextStyle(
            fontSize: AppFontSizes.s14,
            color: LoginHeroTokens.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
