import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';

class LoginPulsingDot extends StatelessWidget {
  const LoginPulsingDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: LoginHeroTokens.primary,
      ),
    );
  }
}
