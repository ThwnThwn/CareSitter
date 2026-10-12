import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogServiceCardColorsServiceRow extends StatelessWidget {
  const CatalogServiceCardColorsServiceRow(
      {super.key,
      required this.colors,
      required this.service,
      required this.formatVnd});
  final ({Color bg, Color fg}) colors;
  final ServiceModel service;
  final String Function(int) formatVnd;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          // Price pill
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 9, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              service.baseHourlyPrice > 0
                  ? '${formatVnd(service.baseHourlyPrice)}/giờ'
                  : 'Liên hệ',
              style: TextStyle(
                color: colors.fg,
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '• tối thiểu ${service.defaultDurationMinutes ~/ 60}h',
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: AppFontSizes.s11,
            ),
          ),
          const Spacer(),
          // Compact CTA
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.compact, vertical: AppSpacing.tight),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Text(
              'Đặt ngay',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}
