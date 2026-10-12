import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:caregiver_app/core/maps/map_tile_config.dart';
import 'package:latlong2/latlong.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftDestinationMap extends StatelessWidget {
  const ShiftDestinationMap(
      {super.key,
      required this.destination,
      required this.ref,
      required this.tiles});
  final LatLng destination;
  final WidgetRef ref;
  final MapTileConfig tiles;

  @override
  Widget build(BuildContext context) => FlutterMap(
        options: MapOptions(
          initialCenter: destination,
          initialZoom: 16,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
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
          MarkerLayer(
            markers: [
              Marker(
                point: destination,
                width: 56,
                height: 68,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.control),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 10,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
}
