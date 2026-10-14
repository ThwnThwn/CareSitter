import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_caregiver_map_presentation_helpers.dart';
import 'dart:math' as math;
import 'live_map_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart' as osm;
import 'package:latlong2/latlong.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/maps/map_tile_attribution.dart';

class LiveCaregiverFallbackMap extends ConsumerWidget {
  const LiveCaregiverFallbackMap(
      {super.key,
      required this.mapController,
      required this.tiles,
      required this.position,
      required this.destination,
      required this.stale,
      required this.heading,
      required this.onReady,
      required this.onPositionChanged});
  final osm.MapController mapController;
  final MapTileConfig tiles;
  final LatLng? position;
  final LatLng destination;
  final bool stale;
  final double? heading;
  final void Function() onReady;
  final void Function(osm.MapCamera, bool) onPositionChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => osm.FlutterMap(
        key: const Key('fallback-live-caregiver-map'),
        mapController: mapController,
        options: osm.MapOptions(
            initialCenter: destination,
            initialZoom: 15,
            onMapReady: onReady,
            onPositionChanged: onPositionChanged,
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
                point: destination,
                width: 42,
                height: 42,
                child: const LiveMapPin(icon: Icons.home_rounded)),
            if (position != null)
              osm.Marker(
                  point: position!,
                  width: 42,
                  height: 42,
                  child: Opacity(
                      opacity: stale ? .5 : 1,
                      child: Transform.rotate(
                          angle: (heading ?? 0) * math.pi / 180,
                          child: const LiveMapPin(
                              icon: Icons.navigation_rounded)))),
          ]),
          Align(
              alignment: Alignment.bottomLeft,
              child: MapTileAttribution(config: tiles)),
        ],
      );
}
