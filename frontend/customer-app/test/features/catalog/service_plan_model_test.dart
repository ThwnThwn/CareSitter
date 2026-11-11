import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đọc phương án theo buổi và tìm đúng giá thấp nhất', () {
    final service = ServiceModel.fromJson({
      'id': 'service-1',
      'code': 'AN_NHIEN',
      'name': 'CareSitter An Nhiên',
      'imageUrl': 'https://cdn.example.test/an-nhien.webp',
      'defaultDurationMinutes': 480,
      'baseHourlyPrice': 0,
      'plans': [
        {
          'id': 'plan-8',
          'code': 'AN_NHIEN_08',
          'name': 'An Nhiên · 8 buổi',
          'billingUnit': 'SESSION_PACKAGE',
          'durationMinutes': 480,
          'includedSessions': 8,
          'totalPrice': 6000000,
          'validityDays': 30,
          'isActive': true,
        },
        {
          'id': 'plan-1',
          'code': 'AN_NHIEN_01',
          'name': 'An Nhiên · 1 buổi',
          'billingUnit': 'SESSION',
          'durationMinutes': 480,
          'includedSessions': 1,
          'totalPrice': 800000,
          'isActive': true,
        },
      ],
    });

    expect(service.plans, hasLength(2));
    expect(service.imageUrl, 'https://cdn.example.test/an-nhien.webp');
    expect(service.minimumPlanPrice, 800000);
    expect(service.activePlans.first.isSessionPackage, isTrue);
    expect(service.activePlans.first.validityDays, 30);
  });

  test('bỏ qua phương án đã ngừng khi tính giá từ', () {
    const service = ServiceModel(
      id: 'service-1',
      code: 'THAN_TRI',
      name: 'CareSitter Thân Trí',
      defaultDurationMinutes: 60,
      plans: [
        ServicePlanModel(
          id: 'inactive',
          code: 'OLD',
          name: 'Giá cũ',
          billingUnit: 'SESSION',
          durationMinutes: 60,
          includedSessions: 1,
          totalPrice: 100000,
          isActive: false,
        ),
        ServicePlanModel(
          id: 'active',
          code: 'CURRENT',
          name: 'Giá hiện hành',
          billingUnit: 'SESSION',
          durationMinutes: 60,
          includedSessions: 1,
          totalPrice: 320000,
        ),
      ],
    );

    expect(service.minimumPlanPrice, 320000);
  });
}
