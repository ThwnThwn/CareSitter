import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_service_card_colors_service_row.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_service_card_service_row.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_service_card_colors_service_panel_body.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_service_card_service_label.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogServiceCardColorsServicePanel extends StatelessWidget {
  const CatalogServiceCardColorsServicePanel(
      {super.key,
      required this.colors,
      required this.service,
      required this.formatVnd});
  final ({Color bg, Color fg}) colors;
  final ServiceModel service;
  final String Function(int) formatVnd;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.control),
        padding: const EdgeInsets.all(AppSpacing.control),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon ──
            CatalogServiceCardColorsServicePanelBody(
                colors: colors, service: service),
            const SizedBox(width: AppSpacing.md),

            // ── Content ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CatalogServiceCardServiceRow(service: service),
                  const SizedBox(height: AppSpacing.tight),

                  // Description
                  CatalogServiceCardServiceLabel(service: service),
                  const SizedBox(height: AppSpacing.compact),

                  // Price + Duration + CTA
                  CatalogServiceCardColorsServiceRow(
                      service: service, formatVnd: formatVnd),
                ],
              ),
            ),
          ],
        ),
      );
}
