import 'package:flutter/material.dart';

class LoginHeroTopDecoration extends StatelessWidget {
  const LoginHeroTopDecoration({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
        left: -30,
        bottom: 20,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      );
}
