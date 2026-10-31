import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/models/catalog_service_filter.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_service_type_filter.dart';

class CatalogServicesAsyncFilterServicesContent extends StatelessWidget {
  const CatalogServicesAsyncFilterServicesContent(
      {super.key,
      required this.servicesAsync,
      required this.selectedFilter,
      required this.onFilterChanged,
      required this.filterServices,
      required this.buildServiceCard});
  final AsyncValue<List<ServiceModel>> servicesAsync;
  final CatalogServiceFilter selectedFilter;
  final ValueChanged<CatalogServiceFilter> onFilterChanged;
  final List<ServiceModel> Function(List<ServiceModel>) filterServices;
  final Widget Function(ServiceModel, int, BuildContext) buildServiceCard;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 3,
        child: servicesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
          error: (e, _) => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Icon(Icons.wifi_off_rounded,
                      color: AppColors.textHint, size: 36),
                  SizedBox(height: AppSpacing.compact),
                  Text(
                    'Không thể tải dịch vụ',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          data: (services) {
            final filtered = filterServices(services);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CatalogServiceTypeFilter(
                  services: services,
                  selected: selectedFilter,
                  onSelected: onFilterChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              color: AppColors.textHint, size: 36),
                          SizedBox(height: AppSpacing.compact),
                          Text(
                            'Không tìm thấy dịch vụ phù hợp',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...filtered.asMap().entries.map(
                        (entry) => buildServiceCard(
                          entry.value,
                          entry.key,
                          context,
                        ),
                      ),
              ],
            );
          },
        ),
      );
}
