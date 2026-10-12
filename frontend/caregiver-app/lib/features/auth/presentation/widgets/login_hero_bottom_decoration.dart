import 'package:flutter/material.dart';

class LoginHeroBottomDecoration extends StatelessWidget {
  const LoginHeroBottomDecoration({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
        right: -40,
        top: -40,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      );
}
