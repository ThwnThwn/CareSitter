import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

class CatalogServicesAsyncFilterServicesContent extends StatelessWidget {
  const CatalogServicesAsyncFilterServicesContent(
      {super.key,
      required this.servicesAsync,
      required this.filterServices,
      required this.buildServiceCard});
  final AsyncValue<List<ServiceModel>> servicesAsync;
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
            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
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
              );
            }
            return Column(
              children: filtered
                  .asMap()
                  .entries
                  .map((e) => buildServiceCard(e.value, e.key, context))
                  .toList(),
            );
          },
        ),
      );
}
