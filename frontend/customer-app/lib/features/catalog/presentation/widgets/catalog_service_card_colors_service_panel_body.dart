import 'package:caresitter_customer/core/widgets/service_image.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogServiceCardColorsServicePanelBody extends StatelessWidget {
  const CatalogServiceCardColorsServicePanelBody(
      {super.key, required this.colors, required this.service});
  final ({Color bg, Color fg}) colors;
  final ServiceModel service;

  @override
  Widget build(BuildContext context) => ServiceImage(
        code: service.code,
        imageUrl: service.imageUrl,
        width: 104,
        height: 132,
        fallbackBackground: colors.bg,
        fallbackForeground: colors.fg,
      );
}
