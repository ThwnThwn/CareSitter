import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_service_card_colors_service_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogScreenServiceCard extends StatelessWidget {
  const CatalogScreenServiceCard(
      {super.key,
      required this.colors,
      required this.service,
      required this.formatVnd});
  final ({Color bg, Color fg}) colors;
  final ServiceModel service;
  final String Function(int) formatVnd;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: CatalogServiceCardColorsServiceContent(
          colors: colors,
          service: service,
          formatVnd: formatVnd,
          callbackAction1: () =>
              context.push(AppRoutes.serviceDetail(service.id))),
    );
  }
}
