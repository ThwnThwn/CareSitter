import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogServiceCardColorsServicePanelBody extends StatelessWidget {
  const CatalogServiceCardColorsServicePanelBody(
      {super.key, required this.colors, required this.service});
  final ({Color bg, Color fg}) colors;
  final ServiceModel service;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 104,
          height: 132,
          child: Image.asset(
            _imageAssetFor(service.code),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(
              color: colors.bg,
              child: Center(
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  color: colors.fg,
                  size: AppFontSizes.s32,
                ),
              ),
            ),
          ),
        ),
      );

  String _imageAssetFor(String code) {
    final normalized = code.toUpperCase();
    if (normalized.contains('NONMED_COMPANION') ||
        normalized.contains('DONGHANH')) {
      return 'assets/images/service-companion.jpg';
    }
    if (normalized.contains('NONMED_ESSENTIAL')) {
      return 'assets/images/service-essential.jpg';
    }
    if (normalized.contains('NONMED_NIGHT') || normalized.contains('DEM')) {
      return 'assets/images/service-night.jpg';
    }
    return 'assets/images/service-day.jpg';
  }
}
