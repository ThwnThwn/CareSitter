import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'map_tile_config.dart';

class MapTileAttribution extends StatelessWidget {
  final MapTileConfig config;
  const MapTileAttribution({super.key, required this.config});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Wrap(spacing: 8, children: [
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
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      );
}
