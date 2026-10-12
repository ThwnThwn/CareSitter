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
  Widget build(BuildContext context) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Center(
          child: Text(
            service.icon,
            style: const TextStyle(fontSize: AppFontSizes.s22),
          ),
        ),
      );
}
