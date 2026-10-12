import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';

class HomePromoCardPromoLabelBody extends StatelessWidget {
  const HomePromoCardPromoLabelBody({super.key, required this.promo});
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
        promo.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: promo.accent,
          fontSize: AppFontSizes.s11,
          fontWeight: FontWeight.w500,
        ),
      );
}
