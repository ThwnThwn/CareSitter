import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomePromoCardPromoRow extends StatelessWidget {
  const HomePromoCardPromoRow(
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
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              promo.hsd,
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: AppFontSizes.s9,
              ),
            ),
          ),
          HomeHoverButton(
            onTap: callbackAction1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: promo.accent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Text(
                'Dùng ngay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSizes.s10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
}
