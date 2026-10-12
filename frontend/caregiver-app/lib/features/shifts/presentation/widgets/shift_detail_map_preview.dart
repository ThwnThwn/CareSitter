import 'package:caregiver_app/features/shifts/presentation/widgets/shift_destination_map.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_destination_label.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_destination_attribution.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/maps/map_tile_config.dart';
import 'package:caregiver_app/core/maps/map_tile_attribution.dart';
import 'package:latlong2/latlong.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailMapPreview extends StatelessWidget {
  const ShiftDetailMapPreview(
      {super.key,
      required this.ref,
      required this.destination,
      required this.openMap,
      required this.booking});
  final WidgetRef ref;
  final LatLng destination;
  final void Function(BuildContext, ShiftModel) openMap;
  final ShiftModel booking;
  @override
  Widget build(BuildContext context) {
    final tiles = ref.watch(mapTileConfigProvider);
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Column(children: [
        Expanded(
            child: Stack(
          children: [
            ShiftDestinationMap(
                destination: destination, ref: ref, tiles: tiles),
            const ShiftDestinationLabel(),
            ShiftDestinationAttribution(
                callbackAction1: () => openMap(context, booking)),
          ],
        )),
        MapTileAttribution(config: tiles)
      ]),
    );
  }
}
