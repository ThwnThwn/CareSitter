import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class LoginHeroSectionContentBody extends StatelessWidget {
  const LoginHeroSectionContentBody({super.key});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Image.network(
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBdZs8HnJiCeklzGb1fp-FfjS1v1n0KzNgKZ9COKpj7PYHRinMo5Z7aAO39hcAaIhJaQZ7GqF7tVuP1WjifjCTbrikR140oMlQc87R4nDrxbeOwjlqVtdwRBVXIFAgwpht7lKoIMw6dUT4HXbU_rcr16HFbndCnr73d7nscE6vfq25dwoyh0wMsLrk8jzUFAUJkHAV0LrfPXX0_7wPdkxsZqptiR0PiRupIN7hDCughZxwIyob9BloB',
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
