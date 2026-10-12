import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';

class LoginOrDivider extends StatelessWidget {
  const LoginOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: LoginHeroTokens.outlineVariant.withValues(alpha: 0.5),
            thickness: 1,
          ),
        ),
        const Flexible(
          flex: 3,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              'Hoặc tiếp tục với',
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontSize: AppFontSizes.s12,
                color: LoginHeroTokens.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: LoginHeroTokens.outlineVariant.withValues(alpha: 0.5),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
