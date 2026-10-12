import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogServiceCardServiceLabel extends StatelessWidget {
  const CatalogServiceCardServiceLabel({super.key, required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context) => Text(
        service.description ?? '',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFontSizes.s12,
          height: 1.45,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
}
