import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class LoginHeroSectionContentBody extends StatelessWidget {
  const LoginHeroSectionContentBody({super.key});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Image.asset(
          'assets/images/service-companion.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: AppColors.heroGradient,
            ),
            child: const Center(
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
        ),
      );
}
