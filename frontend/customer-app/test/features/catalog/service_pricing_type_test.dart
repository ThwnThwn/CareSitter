import 'package:caresitter_customer/features/catalog/domain/service_pricing_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dịch vụ không có phương án được phân loại theo giờ', () {
    expect(
      classifyServicePricingType(
        hasActivePlans: false,
        hasPackagePlan: false,
      ),
      ServicePricingType.hourly,
    );
  });

  test('phương án buổi lẻ được phân loại theo buổi', () {
    expect(
      classifyServicePricingType(
        hasActivePlans: true,
        hasPackagePlan: false,
      ),
      ServicePricingType.session,
    );
  });

  test('phương án nhiều buổi được phân loại combo', () {
    expect(
      classifyServicePricingType(
        hasActivePlans: true,
        hasPackagePlan: true,
      ),
      ServicePricingType.combo,
    );
  });
}
