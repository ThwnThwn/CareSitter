import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';

class LoginSocialButton extends StatelessWidget {
  const LoginSocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    this.onPressed,
  });

  final String label;
  final Widget icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: LoginHeroTokens.onSurface,
          overlayColor: Colors.black.withValues(alpha: 0.04),
          side: BorderSide(
            color: LoginHeroTokens.outlineVariant.withValues(alpha: 0.6),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: Semantics(label: label, excludeSemantics: true, child: icon),
        ),
      ),
    );
  }
}
