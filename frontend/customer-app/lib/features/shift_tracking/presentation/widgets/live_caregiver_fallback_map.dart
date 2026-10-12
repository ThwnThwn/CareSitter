import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_caregiver_map_presentation_helpers.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:latlong2/latlong.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/maps/map_tile_attribution.dart';

class LiveCaregiverFallbackMap extends StatelessWidget {
  const LiveCaregiverFallbackMap(
      {super.key,
      required this.mapController,
      required this.ref,
      required this.tiles,
      required this.pin,
      required this.position,
      required this.routeDestination,
      required this.routeStale,
      required this.routeHeading,
      required this.action1,
      required this.action2});
  final osm.MapController mapController;
  final WidgetRef ref;
  final MapTileConfig tiles;
  final Widget Function(IconData) pin;
  final LatLng? position;
  final LatLng routeDestination;
  final bool routeStale;
  final double? routeHeading;
  final void Function() action1;
  final void Function(osm.MapCamera, bool) action2;
  @override
  Widget build(BuildContext context) => osm.FlutterMap(
        key: const Key('fallback-live-caregiver-map'),
        mapController: mapController,
        options: osm.MapOptions(
            initialCenter: routeDestination,
            initialZoom: 15,
            onMapReady: action1,
            onPositionChanged: action2,
            interactionOptions: const osm.InteractionOptions(
                flags:
                    osm.InteractiveFlag.pinchZoom | osm.InteractiveFlag.drag)),
        children: [
          osm.TileLayer(
              tileProvider: ref.watch(trackingTileProviderProvider),
              urlTemplate: tiles.urlTemplate,
              subdomains: tiles.subdomains,
              retinaMode: tiles.usesCarto,
              maxNativeZoom: tiles.maxNativeZoom,
              userAgentPackageName: 'vn.caresitter.customer'),
          osm.MarkerLayer(markers: [
            osm.Marker(
                point: routeDestination,
                width: 42,
                height: 42,
                child: pin(Icons.home_rounded)),
            if (position != null)
              osm.Marker(
                  point: position!,
                  width: 42,
                  height: 42,
                  child: Opacity(
                      opacity: routeStale ? .5 : 1,
                      child: Transform.rotate(
                          angle: (routeHeading ?? 0) * math.pi / 180,
                          child: pin(Icons.navigation_rounded)))),
          ]),
          Align(
              alignment: Alignment.bottomLeft,
              child: MapTileAttribution(config: tiles)),
        ],
      );
}
