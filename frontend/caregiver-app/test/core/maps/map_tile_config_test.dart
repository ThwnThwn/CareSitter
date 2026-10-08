import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/maps/map_tile_config.dart';

void main() {
  test('CARTO URL uses an encoded key parameter', () {
    const config = MapTileConfig(cartoApiKey: ' token&scope=a+b ');
    expect(Uri.splitQueryString(config.urlTemplate.split('?').last),
        {'key': 'token&scope=a+b'});
    expect(config.subdomains, ['a', 'b', 'c', 'd']);
  });
  test('missing key or explicit OSM uses a URL without credentials', () {
    expect(const MapTileConfig().usesCarto, false);
    expect(
        const MapTileConfig(cartoApiKey: 'key', forceOpenStreetMap: true)
            .urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  });
}
