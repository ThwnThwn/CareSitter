import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:caregiver_app/core/config/env_config.dart';

final mapTileConfigProvider = Provider<MapTileConfig>((ref) => MapTileConfig(
      cartoApiKey: EnvConfig.cartoApiKey,
      forceOpenStreetMap: EnvConfig.mapProvider == 'osm',
    ));
// Cho phép kiểm thử bản đồ mà không gọi CDN thật.
final mapTileProviderProvider = Provider<TileProvider?>((ref) => null);

class MapTileConfig {
  final String cartoApiKey;
  final bool forceOpenStreetMap;
  const MapTileConfig({this.cartoApiKey = '', this.forceOpenStreetMap = false});

  bool get usesCarto => !forceOpenStreetMap && cartoApiKey.trim().isNotEmpty;
  String get urlTemplate => usesCarto
      ? 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=${Uri.encodeQueryComponent(cartoApiKey.trim())}'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  List<String> get subdomains =>
      usesCarto ? const ['a', 'b', 'c', 'd'] : const [];
  int get maxNativeZoom => usesCarto ? 20 : 19;
}
