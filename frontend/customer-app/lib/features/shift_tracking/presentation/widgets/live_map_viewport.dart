import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_map_attribution.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class LiveMapViewport extends StatelessWidget {
  const LiveMapViewport(
      {super.key,
      required this.availability,
      required this.useGoogle,
      required this.googleMap,
      required this.fallbackMap,
      required this.routeLocationLabel,
      required this.tiles,
      required this.mapButton,
      required this.follow,
      required this.routeCaregiverPosition,
      required this.resumeFollow,
      required this.action1});
  final AsyncValue<bool> availability;
  final bool useGoogle;
  final Widget Function() googleMap;
  final Widget Function() fallbackMap;
  final String routeLocationLabel;
  final MapTileConfig tiles;
  final Widget Function(
      {bool active,
      required IconData icon,
      required Key key,
      void Function()? onPressed,
      required String tooltip}) mapButton;
  final bool follow;
  final LatLng? routeCaregiverPosition;
  final void Function() resumeFollow;
  final void Function() action1;

  @override
  Widget build(BuildContext context) => Expanded(
          child: Stack(children: [
        Positioned.fill(
            child: availability.isLoading
                ? const ColoredBox(
                    color: AppColors.primaryContainer,
                    child: Center(child: CircularProgressIndicator()))
                : useGoogle
                    ? googleMap()
                    : fallbackMap()),
        Positioned(
          top: 12,
          left: 12,
          right: 68,
          child: PointerInterceptor(
              child: DecoratedBox(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.compact),
                border: Border.all(color: AppColors.border)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.control, vertical: AppSpacing.sm),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(routeLocationLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: AppFontSizes.s12,
                            fontWeight: FontWeight.w600)),
                    if (!useGoogle)
                      LiveMapAttribution(
                          availability: availability, tiles: tiles),
                  ]),
            ),
          )),
        ),
        Positioned(
            top: 12,
            right: 12,
            child: PointerInterceptor(
                child: Column(children: [
              mapButton(
                  key: const Key('tracking-follow'),
                  tooltip: follow
                      ? 'Đang bám theo chăm sóc viên'
                      : 'Theo dõi chăm sóc viên',
                  icon: Icons.my_location,
                  active: follow && routeCaregiverPosition != null,
                  onPressed:
                      routeCaregiverPosition == null ? null : resumeFollow),
              const SizedBox(height: AppSpacing.sm),
              mapButton(
                  key: const Key('tracking-fit-both'),
                  tooltip: 'Xem cả hai điểm',
                  icon: Icons.zoom_out_map,
                  onPressed: action1),
            ]))),
      ]));
}
