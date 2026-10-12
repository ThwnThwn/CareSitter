import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomePromoCardPromoRowBody extends StatelessWidget {
  const HomePromoCardPromoRowBody({super.key, required this.promo});
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
  Widget build(BuildContext context) => Row(
        children: [
          Text(promo.icon, style: const TextStyle(fontSize: AppFontSizes.s16)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: AppSpacing.tiny),
            decoration: BoxDecoration(
              color: promo.accent,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              promo.badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppFontSizes.s10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}
