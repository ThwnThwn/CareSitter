import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/maps/map_tile_config.dart';
import 'package:latlong2/latlong.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftRouteMap extends ConsumerWidget {
  const ShiftRouteMap(
      {super.key,
      required this.center,
      required this.current,
      required this.tiles,
      required this.destination});
  final LatLng center;
  final LatLng? current;
  final MapTileConfig tiles;
  final LatLng destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: current == null ? 15 : 13.5,
        ),
        children: [
          TileLayer(
            tileProvider: ref.watch(mapTileProviderProvider),
            urlTemplate: tiles.urlTemplate,
            subdomains: tiles.subdomains,
            retinaMode: tiles.usesCarto,
            maxNativeZoom: tiles.maxNativeZoom,
            userAgentPackageName: 'com.caresitter.caregiver',
          ),
          if (current != null)
            PolylineLayer(polylines: [
              Polyline(
                points: [current!, destination],
                color: AppColors.primary,
                strokeWidth: 4,
              ),
            ]),
          MarkerLayer(markers: [
            if (current != null)
              Marker(
                point: current!,
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                    boxShadow: AppShadows.card,
                  ),
                  child: const Icon(Icons.navigation_rounded,
                      color: AppColors.primary, size: 22),
                ),
              ),
            Marker(
              point: destination,
              width: 48,
              height: 48,
              child: const Icon(Icons.location_on_rounded,
                  color: AppColors.error, size: 40),
            ),
          ]),
        ],
      );
}
