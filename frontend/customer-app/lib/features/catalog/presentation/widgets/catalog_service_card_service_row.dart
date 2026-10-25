import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogServiceCardServiceRow extends StatelessWidget {
  const CatalogServiceCardServiceRow({super.key, required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: AppSpacing.tiny),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              service.category,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.tight),
          Text(
            service.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      );
}
