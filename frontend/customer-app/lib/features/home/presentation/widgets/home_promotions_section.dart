import 'package:caresitter_customer/features/home/presentation/widgets/home_promotions_section_row.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_promotions_section_promos_scroll_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomePromotionsSection extends StatelessWidget {
  const HomePromotionsSection({super.key, required this.buildPromoCard});
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
  Widget build(BuildContext context) {
    final promos = [
      (
        title: 'Ưu đãi khách mới',
        subtitle: 'Giảm 20% đơn đầu tiên',
        hsd: 'HSD: 31/10/2026',
        badge: 'Giảm 20%',
        bg: AppColors.primaryContainer,
        accent: AppColors.primary,
        borderColor: AppColors.primary,
        icon: '🎁',
      ),
      (
        title: 'Đặt lịch cuối tuần',
        subtitle: 'Tiết kiệm 50.000đ',
        hsd: 'HSD: 05/10/2026',
        badge: 'Giảm 50k',
        bg: AppColors.warningLight,
        accent: AppColors.warning,
        borderColor: AppColors.warning,
        icon: '🌟',
      ),
      (
        title: 'Giới thiệu bạn bè',
        subtitle: 'Nhận 100.000đ tín dụng',
        hsd: 'Không giới hạn',
        badge: '+100k',
        bg: AppColors.primaryContainer,
        accent: AppColors.primaryDark,
        borderColor: AppColors.primaryDark,
        icon: '👥',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomePromotionsSectionRow(callbackAction1: () {}),
        const SizedBox(height: AppSpacing.inset),
        HomePromotionsSectionPromosScrollContent(
            promos: promos, buildPromoCard: buildPromoCard),
      ],
    );
  }
}
