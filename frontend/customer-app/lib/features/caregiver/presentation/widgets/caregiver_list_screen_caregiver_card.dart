import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_caregiver_card_caregiver_format_currency_content.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_caregiver_card_caregiver_row.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_caregiver_card_caregiver_content.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverListScreenCaregiverCard extends StatelessWidget {
  const CaregiverListScreenCaregiverCard(
      {super.key, required this.caregiver, required this.formatCurrency});
  final CaregiverModel caregiver;
  final String Function(double) formatCurrency;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/caregivers/${caregiver.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.compact),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Avatar + Info ──
            CaregiverListCaregiverCardCaregiverRow(caregiver: caregiver),

            // ── Skills ──
            if (caregiver.distanceLabel != null) ...[
              const SizedBox(height: AppSpacing.control),
              Text('Khoảng ${caregiver.distanceLabel} từ địa chỉ chăm sóc',
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: AppFontSizes.s12)),
            ],
            if (caregiver.skills.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.control),
              CaregiverListCaregiverCardCaregiverContent(caregiver: caregiver),
            ],

            const SizedBox(height: AppSpacing.compact),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.compact),

            // ── Price + Action buttons ──
            CaregiverListCaregiverCardCaregiverFormatCurrencyContent(
                caregiver: caregiver, formatCurrency: formatCurrency),
          ],
        ),
      ),
    );
  }
}
