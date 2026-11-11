import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/domain/service_pricing_type.dart';
import 'package:caresitter_customer/features/catalog/presentation/models/catalog_service_filter.dart';

class CatalogServiceCardColorsServiceRow extends StatelessWidget {
  const CatalogServiceCardColorsServiceRow(
      {super.key, required this.service, required this.formatVnd});
  final ServiceModel service;
  final String Function(int) formatVnd;

  @override
  Widget build(BuildContext context) {
    final pricingType = servicePricingTypeOf(service);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.minimumPlanPrice > 0
                    ? 'Từ ${formatVnd(service.minimumPlanPrice)}/buổi'
                    : service.baseHourlyPrice > 0
                        ? '${formatVnd(service.baseHourlyPrice)}/giờ'
                        : 'Liên hệ',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.micro),
              Text(
                switch (pricingType) {
                  ServicePricingType.combo =>
                    '${service.activePlans.length} phương án · ${_durationLabel(service.defaultDurationMinutes)}/buổi',
                  ServicePricingType.session =>
                    '${_durationLabel(service.defaultDurationMinutes)}/buổi',
                  ServicePricingType.hourly =>
                    'Ca từ ${_durationLabel(service.defaultDurationMinutes)}',
                },
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.s10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.primary,
            size: 19,
            semanticLabel: 'Xem chi tiết',
          ),
        ),
      ],
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes phút';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return '$hours giờ';
    return '$hours giờ $remaining phút';
  }
}
