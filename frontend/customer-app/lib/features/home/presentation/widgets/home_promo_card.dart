import 'package:caresitter_customer/features/home/presentation/widgets/home_promo_card_promo_fields.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomePromoCard extends StatelessWidget {
  const HomePromoCard({super.key, required this.promo});
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
  Widget build(BuildContext context) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4).toDouble();

    return Container(
      width: 170 * textScale,
      constraints: const BoxConstraints(minHeight: 114),
      padding: const EdgeInsets.all(AppSpacing.compact),
      decoration: BoxDecoration(
        color: promo.bg,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(
          color: promo.borderColor.withValues(alpha: 0.22),
        ),
      ),
      child: HomePromoCardPromoFields(promo: promo, callbackAction1: () {}),
    );
  }
}
