import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_map_viewport.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_map_address_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';

class LiveCaregiverMapLayout extends StatelessWidget {
  const LiveCaregiverMapLayout(
      {super.key,
      required this.availability,
      required this.useGoogle,
      required this.googleMap,
      required this.fallbackMap,
      required this.tiles,
      required this.mapButton,
      required this.follow,
      required this.resumeFollow,
      required this.routeLocationLabel,
      required this.routeCaregiverPosition,
      required this.routeAddressLabel,
      required this.action1});
  final AsyncValue<bool> availability;
  final bool useGoogle;
  final Widget Function() googleMap;
  final Widget Function() fallbackMap;
  final MapTileConfig tiles;
  final Widget Function(
      {bool active,
      required IconData icon,
      required Key key,
      void Function()? onPressed,
      required String tooltip}) mapButton;
  final bool follow;
  final void Function() resumeFollow;
  final String routeLocationLabel;
  final LatLng? routeCaregiverPosition;
  final String routeAddressLabel;
  final void Function() action1;
  @override
  Widget build(BuildContext context) => Column(children: [
        LiveMapViewport(
            availability: availability,
            useGoogle: useGoogle,
            googleMap: googleMap,
            fallbackMap: fallbackMap,
            routeLocationLabel: routeLocationLabel,
            tiles: tiles,
            mapButton: mapButton,
            follow: follow,
            routeCaregiverPosition: routeCaregiverPosition,
            resumeFollow: resumeFollow,
            action1: action1),
        LiveMapAddressLabel(routeAddressLabel: routeAddressLabel),
      ]);
}
