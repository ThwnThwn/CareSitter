import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/runtime_config/runtime_config.dart';
import 'package:caresitter_customer/core/runtime_config/runtime_config_service.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_configured_banner.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_service_results.dart';

class ConfigService implements RuntimeConfigService {
  final fetched = Completer<RuntimeConfig>();
  @override
  Future<RuntimeConfig> loadActivated() async => const RuntimeConfig();
  @override
  Future<RuntimeConfig> fetchAndActivate() => fetched.future;
}

void main() {
  testWidgets('activated values hide banner and paginate visible catalog cards',
      (tester) async {
    final service = ConfigService();
    final cards = List.generate(
        5,
        (i) => ServiceModel(
            id: '$i',
            code: '$i',
            name: 'Service $i',
            defaultDurationMinutes: 60));
    await tester.pumpWidget(ProviderScope(
        overrides: [runtimeConfigServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
            home: Scaffold(
                body: Column(children: [
          CatalogConfiguredBanner(builder: () => const Text('Catalog banner')),
          CatalogServiceResults(
              services: cards,
              buildCard: (item, index, context) => Text(item.name)),
        ])))));
    await tester.pumpAndSettle();
    expect(find.text('Catalog banner'), findsOneWidget);
    expect(find.text('Service 4'), findsOneWidget);
    expect(find.text('Trang sau'), findsNothing);
    service.fetched.complete(const RuntimeConfig(
        catalogBannerEnabled: false, catalogPageSize: 2, source: 'remote'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog banner'), findsNothing);
    expect(find.text('Service 0'), findsOneWidget);
    expect(find.text('Service 2'), findsNothing);
    expect(find.text('Trang 1/3'), findsOneWidget);
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(find.text('Service 0'), findsNothing);
    expect(find.text('Service 2'), findsOneWidget);
    expect(find.text('Trang 2/3'), findsOneWidget);
  });
}
