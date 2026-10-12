import 'package:flutter/material.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/map/shift_map_movement_card.dart';

class ShiftRouteOverlay extends StatelessWidget {
  const ShiftRouteOverlay(
      {super.key,
      required this.distance,
      required this.locationStatus,
      required this.loadCurrentPosition,
      required this.openGoogleMaps,
      required this.routeBeneficiaryName,
      required this.routeAddress});
  final String? distance;
  final LocationStatus locationStatus;
  final Future<void> Function() loadCurrentPosition;
  final Future<void> Function() openGoogleMaps;
  final String routeBeneficiaryName;
  final String routeAddress;

  @override
  Widget build(BuildContext context) => Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: ShiftMapMovementCard(
          beneficiaryName: routeBeneficiaryName,
          address: routeAddress,
          distanceLabel: distance,
          status: locationStatus,
          onRetryLocation: loadCurrentPosition,
          onOpenGoogleMaps: openGoogleMaps,
        ),
      );
}
