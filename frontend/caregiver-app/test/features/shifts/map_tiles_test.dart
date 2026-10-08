import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/maps/map_tile_config.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/screens/shift_detail_screen.dart';
import 'package:caregiver_app/features/shifts/presentation/screens/shift_map_screen.dart';

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg=='));
}

class _Shifts extends StateNotifier<List<ShiftModel>>
    implements ShiftListController {
  _Shifts()
      : super([
          const ShiftModel(
            id: 'preview',
            beneficiaryName: 'Nguyễn Văn An',
            caregiverName: 'Trần Thị Hoa',
            caregiverAvatar: 'TH',
            serviceName: 'Chăm sóc tại nhà',
            date: '08/10/2026',
            time: '08:00 – 12:00',
            duration: '4 giờ',
            status: 'confirmed',
            totalPrice: 440000,
            address: '123 Nguyễn Huệ, TP. Hồ Chí Minh',
            addressLatitude: 10.7769,
            addressLongitude: 106.7009,
          )
        ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    for (final name in [
      'flutter.baseflow.com/geolocator',
      'flutter.baseflow.com/geolocator_android'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => false);
    }
  });
  tearDown(() {
    for (final name in [
      'flutter.baseflow.com/geolocator',
      'flutter.baseflow.com/geolocator_android'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), null);
    }
  });
  for (final preview in [false, true]) {
    testWidgets(
        'CARTO ${preview ? 'preview' : 'full map'} shows source credits on a narrow screen',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(overrides: [
        mapTileConfigProvider.overrideWithValue(
            const MapTileConfig(cartoApiKey: 'test-basemap-key')),
        mapTileProviderProvider.overrideWithValue(_Tiles()),
        shiftsProvider.overrideWith((_) => _Shifts()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.4)),
                  child: child!),
              home: preview
                  ? const ShiftDetailScreen(id: 'preview')
                  : const ShiftMapScreen(
                      bookingId: 'preview',
                      beneficiaryName: 'Nguyễn Văn An',
                      address: '123 Nguyễn Huệ, TP. Hồ Chí Minh',
                      destinationLatitude: 10.7769,
                      destinationLongitude: 106.7009,
                    ))));
      await tester.pumpAndSettle();
      final layer = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(layer.urlTemplate, contains('?key=test-basemap-key'));
      expect(layer.subdomains, ['a', 'b', 'c', 'd']);
      expect(find.text('© CARTO'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      if (preview) {
        await tester.ensureVisible(find.byType(FlutterMap));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
