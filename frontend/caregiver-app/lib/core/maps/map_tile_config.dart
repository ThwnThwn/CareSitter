import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:caregiver_app/core/config/env_config.dart';

final mapTileConfigProvider = Provider<MapTileConfig>((ref) => MapTileConfig(
      cartoApiKey: EnvConfig.cartoApiKey,
      forceOpenStreetMap: EnvConfig.mapProvider == 'osm',
      useOsmJapan: EnvConfig.mapProvider == 'osm_jp',
    ));
// Cho phép kiểm thử bản đồ mà không gọi CDN thật.
final mapTileProviderProvider = Provider<TileProvider?>((ref) => null);

class MapTileConfig {
  final String cartoApiKey;
  final bool forceOpenStreetMap;
  final bool useOsmJapan;
  const MapTileConfig({
    this.cartoApiKey = '',
    this.forceOpenStreetMap = false,
    this.useOsmJapan = false,
  });

  bool get usesCarto =>
      !forceOpenStreetMap && !useOsmJapan && cartoApiKey.trim().isNotEmpty;
  String get urlTemplate => useOsmJapan
      ? 'https://tile.openstreetmap.jp/styles/osm-bright/{z}/{x}/{y}.png'
      : usesCarto
          ? 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=${Uri.encodeQueryComponent(cartoApiKey.trim())}'
          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  List<String> get subdomains =>
      usesCarto ? const ['a', 'b', 'c', 'd'] : const [];
  int get maxNativeZoom => usesCarto ? 20 : 19;
}
