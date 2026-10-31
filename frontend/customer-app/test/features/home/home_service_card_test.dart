import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/home/presentation/models/home_service_accent.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_service_card.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_services_section.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _services = <ServiceModel>[
  ServiceModel(
    id: 'companion',
    code: 'NONMED_COMPANION',
    name: 'Đồng hành linh hoạt',
    defaultDurationMinutes: 240,
    baseHourlyPrice: 80000,
  ),
  ServiceModel(
    id: 'essential',
    code: 'NONMED_ESSENTIAL',
    name: 'Hỗ trợ thiết yếu',
    defaultDurationMinutes: 120,
    baseHourlyPrice: 90000,
  ),
  ServiceModel(
    id: 'day',
    code: 'NONMED_DAY',
    name: 'Chăm sóc ban ngày',
    defaultDurationMinutes: 480,
    baseHourlyPrice: 70000,
  ),
  ServiceModel(
    id: 'night',
    code: 'NONMED_NIGHT',
    name: 'Hỗ trợ ban đêm',
    defaultDurationMinutes: 480,
    baseHourlyPrice: 85000,
  ),
];

const _allServices = <ServiceModel>[
  ..._services,
  ServiceModel(
    id: 'rehab',
    code: 'THAN_TRI',
    name: 'Phục hồi Thân Trí',
    defaultDurationMinutes: 90,
    baseHourlyPrice: 200000,
  ),
  ServiceModel(
    id: 'nursing',
    code: 'AN_KHANG',
    name: 'Điều dưỡng An Khang',
    defaultDurationMinutes: 120,
    baseHourlyPrice: 220000,
  ),
];

const _expectedAssets = <String, String>{
  'NONMED_COMPANION': 'assets/images/service-companion.jpg',
  'NONMED_ESSENTIAL': 'assets/images/service-essential.jpg',
  'NONMED_DAY': 'assets/images/service-day.jpg',
  'NONMED_NIGHT': 'assets/images/service-night.jpg',
};

void main() {
  testWidgets('featured section exposes every service and reports real count',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [serviceStoreProvider.overrideWith(_AllServices.new)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: HomeServicesSection(
              serviceAccent: (_) => const HomeServiceAccent(
                AppColors.primary,
                AppColors.primaryContainer,
              ),
              buildServiceCard: (service, _) => SizedBox(
                width: 156,
                child: Text(service.name),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('6 gói chăm sóc tại nhà dành cho gia đình'),
      findsOneWidget,
    );
    for (final service in _allServices) {
      expect(find.text(service.name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('featured cards show four images, seeded ratings and real prices',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final service in _services)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: HomeServiceCard(
                      service: service,
                      accent: const HomeServiceAccent(
                        AppColors.primary,
                        AppColors.primaryContainer,
                      ),
                      formatVnd: (value) => '${value ~/ 1000}.000đ',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final service in _services) {
      expect(find.text(service.name), findsOneWidget);
      final image = tester.widget<Image>(
        find.byKey(Key('home-service-image-${service.code}')),
      );
      expect(
        (image.image as AssetImage).assetName,
        _expectedAssets[service.code],
      );
    }

    expect(find.text('Từ 80.000đ/giờ'), findsOneWidget);
    expect(find.text('4.9'), findsNWidgets(2));
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);

    final nameTopPositions = _services
        .map((service) => tester.getTopLeft(find.text(service.name)).dy)
        .toSet();
    final priceTopPositions = _services
        .map(
          (service) => tester
              .getTopLeft(
                find.text(
                  'Từ ${service.baseHourlyPrice ~/ 1000}.000đ/giờ',
                ),
              )
              .dy,
        )
        .toSet();
    expect(nameTopPositions, hasLength(1));
    expect(priceTopPositions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('featured card keeps its content inside rounded corners on hover',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeServiceCard(
            service: _services.first,
            accent: const HomeServiceAccent(
              AppColors.primary,
              AppColors.primaryContainer,
            ),
            formatVnd: (value) => '${value ~/ 1000}.000đ',
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
    expect(clip.borderRadius, BorderRadius.circular(AppRadius.lg));
    expect(clip.clipBehavior, Clip.antiAlias);
  });
}

class _AllServices extends ServiceStore {
  @override
  Future<List<ServiceModel>> build() async => _allServices;
}
