import 'package:caresitter_customer/features/home/presentation/widgets/home_promo_card_promo_row.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_promo_card_promo_row_body.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_promo_card_promo_label.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_promo_card_promo_label_body.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomePromoCardPromoFields extends StatelessWidget {
  const HomePromoCardPromoFields(
      {super.key, required this.promo, required this.callbackAction1});
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
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomePromoCardPromoRowBody(promo: promo),
          const SizedBox(height: AppSpacing.tight),
          HomePromoCardPromoLabel(promo: promo),
          HomePromoCardPromoLabelBody(promo: promo),
          const Spacer(),
          HomePromoCardPromoRow(promo: promo, callbackAction1: callbackAction1),
        ],
      );
}
