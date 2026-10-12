import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_social_button.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_google_icon.dart';

class LoginSocialLoginRow extends ConsumerWidget {
  const LoginSocialLoginRow({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // ── Google button ──
        Expanded(
          child: LoginSocialButton(
            key: const ValueKey('google-sign-in-button'),
            label: 'Đăng nhập bằng Google',
            icon: const LoginGoogleIcon(),
            enabled: enabled,
            onPressed: () =>
                ref.read(loginControllerProvider.notifier).loginWithGoogle(),
          ),
        ),
        const SizedBox(width: AppSpacing.compact),

        // ── Apple button ──
        Expanded(
          child: LoginSocialButton(
            key: const ValueKey('apple-sign-in-button'),
            label: 'Đăng nhập bằng Apple',
            icon: const Icon(
              Icons.apple_rounded,
              size: 22,
              color: LoginHeroTokens.onSurface,
            ),
            enabled: enabled,
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}
