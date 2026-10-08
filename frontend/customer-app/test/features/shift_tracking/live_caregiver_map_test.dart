import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:caresitter_customer/core/maps/google_maps_runtime.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_caregiver_map.dart';

class FakeGoogleMapPlatform extends GoogleMapsFlutterPlatform {
  final created = <int>{};
  final cameraUpdates = <CameraUpdate>[];
  final markers = <MarkerId, Marker>{};

  @override
  Widget buildViewWithConfiguration(
      int creationId, PlatformViewCreatedCallback onPlatformViewCreated,
      {required MapWidgetConfiguration widgetConfiguration,
      MapConfiguration mapConfiguration = const MapConfiguration(),
      MapObjects mapObjects = const MapObjects()}) {
    if (created.add(creationId)) {
      for (final marker in mapObjects.markers) {
        markers[marker.markerId] = marker;
      }
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onPlatformViewCreated(creationId));
    }
    return const ColoredBox(color: AppColors.primaryContainer);
  }

  @override
  Future<void> init(int mapId) async {}
  @override
  void dispose({required int mapId}) {}
  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate,
          {required int mapId}) async =>
      cameraUpdates.add(cameraUpdate);
  @override
  Future<void> moveCamera(CameraUpdate cameraUpdate,
          {required int mapId}) async =>
      cameraUpdates.add(cameraUpdate);
  @override
  Future<void> updateMapConfiguration(MapConfiguration configuration,
      {required int mapId}) async {}
  @override
  Future<void> updateMarkers(MarkerUpdates markerUpdates,
      {required int mapId}) async {
    for (final id in markerUpdates.markerIdsToRemove) {
      markers.remove(id);
    }
    for (final marker in {
      ...markerUpdates.markersToAdd,
      ...markerUpdates.markersToChange
    }) {
      markers[marker.markerId] = marker;
    }
  }

  @override
  Future<void> updatePolygons(PolygonUpdates polygonUpdates,
      {required int mapId}) async {}
  @override
  Future<void> updatePolylines(PolylineUpdates polylineUpdates,
      {required int mapId}) async {}
  @override
  Future<void> updateCircles(CircleUpdates circleUpdates,
      {required int mapId}) async {}
  @override
  Future<void> updateHeatmaps(HeatmapUpdates heatmapUpdates,
      {required int mapId}) async {}
  @override
  Future<void> updateTileOverlays(
      {required Set<TileOverlay> newTileOverlays, required int mapId}) async {}
  @override
  Future<void> updateClusterManagers(
      ClusterManagerUpdates clusterManagerUpdates,
      {required int mapId}) async {}
  @override
  Future<void> updateGroundOverlays(GroundOverlayUpdates groundOverlayUpdates,
      {required int mapId}) async {}
  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();
  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      const Stream.empty();
  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      const Stream.empty();
}

const destination = geo.LatLng(10.7769, 106.7009);
const first = geo.LatLng(10.79, 106.71);
const second = geo.LatLng(10.785, 106.705);

class TestTileProvider extends osm.TileProvider {
  @override
  ImageProvider getImage(
          osm.TileCoordinates coordinates, osm.TileLayer options) =>
      MemoryImage(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg=='));
}

Widget mapApp(ProviderContainer container, geo.LatLng? point,
        {bool stale = false}) =>
    UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.4)),
                child: child!),
            home: Scaffold(
                body: SizedBox(
                    height: 360,
                    child: LiveCaregiverMap(
                        destination: destination,
                        caregiverPosition: point,
                        heading: 90,
                        stale: stale,
                        locationLabel: stale
                            ? 'Vị trí cũ · 2 phút trước'
                            : 'Đang cập nhật · 3 giây trước',
                        addressLabel:
                            '123 Nguyễn Huệ, phường Bến Nghé, TP. Hồ Chí Minh')))));

void main() {
  late GoogleMapsFlutterPlatform original;
  late FakeGoogleMapPlatform platform;
  setUp(() {
    original = GoogleMapsFlutterPlatform.instance;
    platform = FakeGoogleMapPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
  });
  tearDown(() => GoogleMapsFlutterPlatform.instance = original);

  testWidgets(
      'Google markers animate, follow pauses for gestures and resumes explicitly',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
        overrides: [googleMapsReadyProvider.overrideWith((_) async => true)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(mapApp(container, first));
    await tester.pumpAndSettle();
    expect(
        platform.markers.keys,
        containsAll(
            [const MarkerId('destination'), const MarkerId('caregiver')]));
    expect(platform.cameraUpdates, isNotEmpty);
    final initialCameras = platform.cameraUpdates.length;
    await tester.pumpWidget(mapApp(container, second));
    await tester.pumpAndSettle();
    expect(platform.markers[const MarkerId('caregiver')]!.position,
        const LatLng(10.785, 106.705));
    expect(platform.markers[const MarkerId('caregiver')]!.rotation, 90);
    expect(platform.cameraUpdates.length, greaterThan(initialCameras));

    await tester.tapAt(
        tester.getCenter(find.byKey(const Key('google-live-caregiver-map'))));
    await tester.pump();
    final pausedCameras = platform.cameraUpdates.length;
    await tester.pumpWidget(mapApp(container, first));
    await tester.pumpAndSettle();
    expect(platform.cameraUpdates.length, pausedCameras);
    expect(platform.markers[const MarkerId('caregiver')]!.position,
        const LatLng(10.79, 106.71));
    await tester.tap(find.byKey(const Key('tracking-follow')));
    await tester.pumpAndSettle();
    expect(platform.cameraUpdates.length, greaterThan(pausedCameras));
    await tester.pumpWidget(mapApp(container, second));
    await tester.pumpAndSettle();
    expect(find.byType(google.GoogleMap), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'stale GPS cannot move camera and clearing GPS removes native marker',
      (tester) async {
    final container = ProviderContainer(
        overrides: [googleMapsReadyProvider.overrideWith((_) async => true)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(mapApp(container, first));
    await tester.pumpAndSettle();
    final cameraCount = platform.cameraUpdates.length;
    await tester.pumpWidget(mapApp(container, second, stale: true));
    await tester.pumpAndSettle();
    expect(platform.cameraUpdates.length, cameraCount);
    expect(platform.markers[const MarkerId('caregiver')]!.alpha, .5);
    expect(find.text('Vị trí cũ · 2 phút trước'), findsOneWidget);
    await tester.pumpWidget(mapApp(container, null));
    await tester.pumpAndSettle();
    expect(platform.markers.containsKey(const MarkerId('caregiver')), false);
    expect(platform.markers.containsKey(const MarkerId('destination')), true);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'missing Google key uses fallback with usable controls at narrow widths',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      googleMapsReadyProvider.overrideWith((_) async => false),
      trackingTileProviderProvider.overrideWithValue(TestTileProvider())
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(mapApp(container, first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
        find.byKey(const Key('fallback-live-caregiver-map')), findsOneWidget);
    expect(find.text('Bản đồ OpenStreetMap'), findsOneWidget);
    expect(find.byType(google.GoogleMap), findsNothing);
    await tester.tap(find.byKey(const Key('tracking-fit-both')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('CARTO stays primary and attribution stays visible at large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var googleLoads = 0;
    final container = ProviderContainer(overrides: [
      mapTileConfigProvider.overrideWithValue(
          const MapTileConfig(cartoApiKey: 'test-basemap-key')),
      googleMapsLoaderProvider.overrideWithValue(() async {
        googleLoads++;
        return true;
      }),
      trackingTileProviderProvider.overrideWithValue(TestTileProvider()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(mapApp(container, first));
    await tester.pumpAndSettle();
    final layer = tester.widget<osm.TileLayer>(find.byType(osm.TileLayer));
    expect(layer.urlTemplate, contains('?key=test-basemap-key'));
    expect(layer.subdomains, ['a', 'b', 'c', 'd']);
    expect(googleLoads, 0);
    expect(find.byType(google.GoogleMap), findsNothing);
    expect(find.text('CARTO Voyager'), findsOneWidget);
    expect(find.text('© CARTO'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
