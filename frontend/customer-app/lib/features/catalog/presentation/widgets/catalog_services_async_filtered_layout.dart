import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_services_async_filtered_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogServicesAsyncFilteredLayout extends StatelessWidget {
  const CatalogServicesAsyncFilteredLayout(
      {super.key,
      required this.buildSearchBar,
      required this.buildBanner,
      required this.servicesAsync,
      required this.filtered,
      required this.buildServiceCard});
  final Widget Function() buildSearchBar;
  final Widget Function() buildBanner;
  final AsyncValue<List<ServiceModel>> servicesAsync;
  final List<ServiceModel> Function(List<ServiceModel>) filtered;
  final Widget Function(ServiceModel, int, BuildContext) buildServiceCard;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: CatalogServicesAsyncFilteredContent(
            buildSearchBar: buildSearchBar,
            buildBanner: buildBanner,
            servicesAsync: servicesAsync,
            filtered: filtered,
            buildServiceCard: buildServiceCard),
      );
}
