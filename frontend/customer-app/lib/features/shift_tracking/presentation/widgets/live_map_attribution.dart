import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class LiveMapAttribution extends StatelessWidget {
  const LiveMapAttribution(
      {super.key, required this.availability, required this.tiles});
  final AsyncValue<bool> availability;
  final MapTileConfig tiles;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.tiny),
            Text(
                availability.isLoading ? 'Đang mở Google Maps...' : tiles.label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.s11)),
          ]);
}
