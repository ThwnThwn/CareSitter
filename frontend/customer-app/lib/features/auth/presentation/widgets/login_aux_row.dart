import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
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
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final scaledLabelSize =
            MediaQuery.textScalerOf(context).scale(AppFontSizes.s12).toDouble();
        final stackActions =
            constraints.maxWidth < 320 && scaledLabelSize > AppFontSizes.s14;
        final remember = _RememberLoginControl(
          isLoading: isLoading,
          rememberLogin: rememberLogin,
          onChanged: onRememberLoginChanged,
        );
        final forgotPassword = _ForgotPasswordButton(isLoading: isLoading);

        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              remember,
              Align(
                alignment: Alignment.centerRight,
                child: forgotPassword,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: remember),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: forgotPassword,
              ),
            ),
          ],
        );
      });
}

class _RememberLoginControl extends StatelessWidget {
  const _RememberLoginControl({
    required this.isLoading,
    required this.rememberLogin,
    required this.onChanged,
  });

  final bool isLoading;
  final bool rememberLogin;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: isLoading ? null : () => onChanged(!rememberLogin),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: rememberLogin,
                  onChanged:
                      isLoading ? null : (value) => onChanged(value ?? false),
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
      );
}

class _ForgotPasswordButton extends StatelessWidget {
  const _ForgotPasswordButton({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed:
            isLoading ? null : () => context.push(AppRoutes.forgotPassword),
        style: TextButton.styleFrom(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
        ),
        child: const Text(
          'Quên mật khẩu?',
          textAlign: TextAlign.end,
          softWrap: false,
          style: TextStyle(
            fontSize: AppFontSizes.s12,
            fontWeight: FontWeight.w600,
            color: LoginHeroTokens.primaryDeep,
          ),
        ),
      );
}
