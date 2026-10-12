import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomePromotionsSectionPromosScrollContent extends StatelessWidget {
  const HomePromotionsSectionPromosScrollContent(
      {super.key, required this.promos, required this.buildPromoCard});
  final List<
      ({
        Color accent,
        String badge,
        Color bg,
        Color borderColor,
        String hsd,
        String icon,
        String subtitle,
        String title
      })> promos;
  final Widget Function(
      ({
        Color accent,
        String badge,
        Color bg,
        Color borderColor,
        String hsd,
        String icon,
        String subtitle,
        String title
      })) buildPromoCard;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (var i = 0; i < promos.length; i++) ...[
                buildPromoCard(promos[i]),
                if (i != promos.length - 1)
                  const SizedBox(width: AppSpacing.control),
              ],
            ],
          ),
        ),
      );
}
