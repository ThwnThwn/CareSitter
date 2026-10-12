import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomePromotionsSectionRow extends StatelessWidget {
  const HomePromotionsSectionRow({super.key, required this.callbackAction1});
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
            child: Text(
              'Ưu đãi & Khuyến mãi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          HomeHoverButton(
            onTap: callbackAction1,
            child: const Text(
              'Xem tất cả',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
