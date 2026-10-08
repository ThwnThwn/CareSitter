import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/config/env_config.dart';

final mapProviderSelectionProvider =
    Provider<String>((ref) => EnvConfig.mapProvider);
final mapTileConfigProvider = Provider<MapTileConfig>((ref) => MapTileConfig(
      cartoApiKey: EnvConfig.cartoApiKey,
      forceOpenStreetMap: ref.watch(mapProviderSelectionProvider) == 'osm',
    ));

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
  String get label => usesCarto ? 'CARTO Voyager' : 'Bản đồ OpenStreetMap';
}
