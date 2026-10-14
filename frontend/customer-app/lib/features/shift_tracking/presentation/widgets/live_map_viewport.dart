import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'live_map_status_banner.dart';
import 'live_map_action_button.dart';

class LiveMapViewport extends StatelessWidget {
  const LiveMapViewport(
      {super.key,
      required this.map,
      required this.availability,
      required this.useGoogle,
      required this.tiles,
      required this.locationLabel,
      required this.follow,
      required this.hasPosition,
      required this.onResumeFollow,
      required this.onFitBoth});
  final Widget map;
  final AsyncValue<bool> availability;
  final bool useGoogle, follow, hasPosition;
  final MapTileConfig tiles;
  final String locationLabel;
  final VoidCallback onResumeFollow, onFitBoth;

  @override
  Widget build(BuildContext context) => Expanded(
          child: Stack(children: [
        Positioned.fill(
            child: availability.isLoading
                ? const ColoredBox(
                    color: AppColors.primaryContainer,
                    child: Center(child: CircularProgressIndicator()))
                : map),
        Positioned(
            top: 12,
            left: 12,
            right: 68,
            child: LiveMapStatusBanner(
                availability: availability,
                useGoogle: useGoogle,
                tiles: tiles,
                locationLabel: locationLabel)),
        Positioned(
            top: 12,
            right: 12,
            child: PointerInterceptor(
                child: Column(children: [
              LiveMapActionButton(
                  key: const Key('tracking-follow'),
                  tooltip: follow
                      ? 'Đang bám theo chăm sóc viên'
                      : 'Theo dõi chăm sóc viên',
                  icon: Icons.my_location,
                  active: follow && hasPosition,
                  onPressed: hasPosition ? onResumeFollow : null),
              const SizedBox(height: AppSpacing.sm),
              LiveMapActionButton(
                  key: const Key('tracking-fit-both'),
                  tooltip: 'Xem cả hai điểm',
                  icon: Icons.zoom_out_map,
                  onPressed: onFitBoth),
            ]))),
      ]));
}
