import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/maps/map_tile_config.dart';

class MapTileAttribution extends StatelessWidget {
  final MapTileConfig config;
  const MapTileAttribution({super.key, required this.config});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Wrap(spacing: AppSpacing.sm, children: [
            _source('© OpenStreetMap contributors',
                'https://www.openstreetmap.org/copyright'),
            if (config.usesCarto)
              _source('© CARTO', 'https://carto.com/attribution/'),
          ]),
        ),
      );

  Widget _source(String label, String url) => InkWell(
        onTap: () => launchUrl(Uri.parse(url)),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: AppFontSizes.s11)),
      );
}
