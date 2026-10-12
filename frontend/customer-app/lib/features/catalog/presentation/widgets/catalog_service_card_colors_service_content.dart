import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_service_card_colors_service_panel.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogServiceCardColorsServiceContent extends StatelessWidget {
  const CatalogServiceCardColorsServiceContent(
      {super.key,
      required this.colors,
      required this.service,
      required this.formatVnd,
      required this.callbackAction1});
  final ({Color bg, Color fg}) colors;
  final ServiceModel service;
  final String Function(int) formatVnd;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: callbackAction1,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CatalogServiceCardColorsServicePanel(
            colors: colors, service: service, formatVnd: formatVnd),
      );
}
