import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/domain/service_pricing_type.dart';

enum CatalogServiceFilter { all, hourly, session, combo }

extension CatalogServiceFilterView on CatalogServiceFilter {
  String get label => switch (this) {
        CatalogServiceFilter.all => 'Tất cả',
        CatalogServiceFilter.hourly => 'Theo giờ',
        CatalogServiceFilter.session => 'Theo buổi',
        CatalogServiceFilter.combo => 'Combo',
      };

  bool matches(ServiceModel service) {
    final pricingType = servicePricingTypeOf(service);
    return switch (this) {
      CatalogServiceFilter.all => true,
      CatalogServiceFilter.hourly => pricingType == ServicePricingType.hourly,
      CatalogServiceFilter.session => pricingType == ServicePricingType.session,
      CatalogServiceFilter.combo => pricingType == ServicePricingType.combo,
    };
  }
}

extension ServicePricingTypeView on ServicePricingType {
  String get label => switch (this) {
        ServicePricingType.hourly => 'Theo giờ',
        ServicePricingType.session => 'Theo buổi',
        ServicePricingType.combo => 'Combo',
      };
}

ServicePricingType servicePricingTypeOf(ServiceModel service) {
  final activePlans = service.activePlans;
  return classifyServicePricingType(
    hasActivePlans: activePlans.isNotEmpty,
    hasPackagePlan: activePlans.any(
      (plan) => plan.isSessionPackage || plan.includedSessions > 1,
    ),
  );
}
