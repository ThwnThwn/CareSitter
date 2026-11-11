import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/models/catalog_service_filter.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_service_type_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hiện số lượng từng loại và trả filter được chọn',
      (tester) async {
    CatalogServiceFilter? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CatalogServiceTypeFilter(
            services: const [
              ServiceModel(
                id: 'hourly',
                code: 'NONMED_COMPANION',
                name: 'Đồng hành',
                defaultDurationMinutes: 60,
              ),
              ServiceModel(
                id: 'session',
                code: 'THAN_TRI',
                name: 'Thân Trí',
                defaultDurationMinutes: 60,
                plans: [
                  ServicePlanModel(
                    id: 'single',
                    code: 'THAN_TRI_01',
                    name: 'Một buổi',
                    billingUnit: 'SESSION',
                    durationMinutes: 60,
                    includedSessions: 1,
                    totalPrice: 320000,
                  ),
                ],
              ),
              ServiceModel(
                id: 'combo',
                code: 'AN_NHIEN',
                name: 'An Nhiên',
                defaultDurationMinutes: 480,
                plans: [
                  ServicePlanModel(
                    id: 'package',
                    code: 'AN_NHIEN_08',
                    name: 'Tám buổi',
                    billingUnit: 'SESSION_PACKAGE',
                    durationMinutes: 480,
                    includedSessions: 8,
                    totalPrice: 6000000,
                  ),
                ],
              ),
            ],
            selected: CatalogServiceFilter.all,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('Tất cả 3'), findsOneWidget);
    expect(find.text('Theo giờ 1'), findsOneWidget);
    expect(find.text('Theo buổi 1'), findsOneWidget);
    expect(find.text('Combo 1'), findsOneWidget);

    await tester.tap(find.text('Combo 1'));
    expect(selected, CatalogServiceFilter.combo);
  });
}
