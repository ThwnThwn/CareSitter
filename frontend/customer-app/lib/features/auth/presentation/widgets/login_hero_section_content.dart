import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_pulsing_dot.dart';

class LoginHeroSectionContent extends StatelessWidget {
  const LoginHeroSectionContent({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
        bottom: 40,
        left: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact, vertical: 5),
          decoration: BoxDecoration(
            color: LoginHeroTokens.surfaceLow,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: LoginHeroTokens.primary.withValues(alpha: 0.25),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoginPulsingDot(),
              SizedBox(width: 7),
              Text(
                'Đồng hành & Chăm sóc tận tâm',
                style: TextStyle(
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w500,
                  color: LoginHeroTokens.primaryDeep,
                ),
              ),
            ],
          ),
        ),
      );
}
