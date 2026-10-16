import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';

class LoginAuxRow extends StatelessWidget {
  const LoginAuxRow({
    super.key,
    required this.isLoading,
    required this.rememberLogin,
    required this.onRememberLoginChanged,
  });

  final bool isLoading;
  final bool rememberLogin;
  final ValueChanged<bool> onRememberLoginChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            onTap:
                isLoading ? null : () => onRememberLoginChanged(!rememberLogin),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: rememberLogin,
                    onChanged: isLoading
                        ? null
                        : (value) => onRememberLoginChanged(value ?? false),
                    activeColor: LoginHeroTokens.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    side: const BorderSide(
                      color: LoginHeroTokens.outlineVariant,
                      width: 1.5,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Ghi nhớ đăng nhập',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: AppFontSizes.s12,
                      color: LoginHeroTokens.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: TextButton(
            onPressed:
                isLoading ? null : () => context.push('/auth/forgot-password'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs, vertical: AppSpacing.micro),
              minimumSize: const Size(44, 44),
            ),
            child: const Text(
              'Quên mật khẩu?',
              textAlign: TextAlign.end,
              softWrap: true,
              style: TextStyle(
                fontSize: AppFontSizes.s12,
                fontWeight: FontWeight.w600,
                color: LoginHeroTokens.primaryDeep,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
