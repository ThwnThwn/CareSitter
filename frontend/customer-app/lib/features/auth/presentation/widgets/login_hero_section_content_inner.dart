import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class LoginHeroSectionContentInner extends StatelessWidget {
  const LoginHeroSectionContentInner({super.key});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.45, 1.0],
              colors: [
                AppColors.textPrimary.withValues(alpha: 0.60),
                AppColors.textPrimary.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.90),
              ],
            ),
          ),
        ),
      );
}
