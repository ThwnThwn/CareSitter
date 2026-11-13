import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class BrandIntroWordmark extends StatelessWidget {
  const BrandIntroWordmark({super.key, required this.disableAnimations});

  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    const brandName = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Care',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          TextSpan(
            text: 'Sitter',
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
      key: ValueKey('caresitter-logo-name'),
      maxLines: 1,
      style: TextStyle(
        fontSize: AppFontSizes.s26,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    );
    return disableAnimations
        ? brandName
        : brandName.animate().fadeIn(delay: 180.ms, duration: 360.ms).slideY(
              begin: 0.24,
              end: 0,
              delay: 180.ms,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            );
  }
}
