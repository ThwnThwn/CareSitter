import 'package:flutter/material.dart';

class LoginHero extends StatelessWidget {
  const LoginHero({super.key});

  static const _bannerAspectRatio = 1376 / 768;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'CareSitter - Chăm sóc tin cậy cho người thân yêu',
        child: AspectRatio(
          aspectRatio: _bannerAspectRatio,
          child: Image.asset(
            'assets/images/caregiver-login-banner.png',
            width: double.infinity,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      );
}
