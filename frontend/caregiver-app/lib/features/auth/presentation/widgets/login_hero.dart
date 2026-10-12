import 'package:caregiver_app/features/auth/presentation/widgets/login_brand_header.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_hero_top_decoration.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_hero_bottom_decoration.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class LoginHero extends StatelessWidget {
  const LoginHero({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: 240,
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        child: const Stack(
          children: [
            LoginHeroBottomDecoration(),
            LoginHeroTopDecoration(),
            LoginBrandHeader(),
          ],
        ),
      );
}
