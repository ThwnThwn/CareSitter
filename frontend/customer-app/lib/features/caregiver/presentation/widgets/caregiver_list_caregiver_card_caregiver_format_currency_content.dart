import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverListCaregiverCardCaregiverFormatCurrencyContent
    extends StatelessWidget {
  const CaregiverListCaregiverCardCaregiverFormatCurrencyContent(
      {super.key, required this.caregiver, required this.formatCurrency});
  final CaregiverModel caregiver;
  final String Function(double) formatCurrency;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final price = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Giá dịch vụ',
              style: TextStyle(
                  color: AppColors.textHint, fontSize: AppFontSizes.s11),
            ),
            Text(
              caregiver.hourlyRateExpected != null
                  ? '${formatCurrency(caregiver.hourlyRateExpected!.toDouble())}/giờ'
                  : 'Liên hệ',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
        final actions = <Widget>[
          OutlinedButton(
            onPressed: () => context.push('/caregivers/${caregiver.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.control),
              minimumSize: Size.zero,
            ),
            child: const Text('Xem hồ sơ',
                style: TextStyle(
                    fontSize: AppFontSizes.s13, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () =>
                context.push('/booking/new?caregiverId=${caregiver.id}'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text('Đặt ngay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.control),
              minimumSize: Size.zero,
              elevation: 0,
            ),
          ),
        ];
        final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
        if (constraints.maxWidth < 360 * textScale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              price,
              const SizedBox(height: AppSpacing.control),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        }
        return Row(children: [
          Expanded(child: price),
          actions[0],
          const SizedBox(width: AppSpacing.sm),
          actions[1],
        ]);
      });
}
