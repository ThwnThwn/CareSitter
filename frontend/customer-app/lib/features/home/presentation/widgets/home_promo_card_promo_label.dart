import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomePromoCardPromoLabel extends StatelessWidget {
  const HomePromoCardPromoLabel({super.key, required this.promo});
  final ({
    Color accent,
    String badge,
    Color bg,
    Color borderColor,
    String hsd,
    String icon,
    String subtitle,
    String title
  }) promo;

  @override
  Widget build(BuildContext context) => Text(
        promo.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppFontSizes.s12,
          fontWeight: FontWeight.w700,
        ),
      );
}
