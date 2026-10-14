import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'live_map_attribution.dart';

class LiveMapStatusBanner extends StatelessWidget {
  const LiveMapStatusBanner(
      {super.key,
      required this.availability,
      required this.useGoogle,
      required this.tiles,
      required this.locationLabel});
  final AsyncValue<bool> availability;
  final bool useGoogle;
  final MapTileConfig tiles;
  final String locationLabel;
  @override
  Widget build(BuildContext context) => PointerInterceptor(
          child: DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.compact),
            border: Border.all(color: AppColors.border)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.control, vertical: AppSpacing.sm),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(locationLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: AppFontSizes.s12,
                    fontWeight: FontWeight.w600)),
            if (!useGoogle)
              LiveMapAttribution(availability: availability, tiles: tiles),
          ]),
        ),
      ));
}
