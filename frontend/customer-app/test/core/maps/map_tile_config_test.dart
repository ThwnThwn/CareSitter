import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/maps/map_tile_config.dart';
import 'package:caresitter_customer/core/maps/google_maps_runtime.dart';

void main() {
  test('key is encoded without turning reserved characters into URL parameters',
      () {
    const config = MapTileConfig(cartoApiKey: ' token&scope=a+b ');
    final query = config.urlTemplate.split('?').last;
    expect(Uri.splitQueryString(query), {'key': 'token&scope=a+b'});
    expect(config.usesCarto, true);
  });
  test('missing key and explicit OSM stay off CARTO', () {
    expect(const MapTileConfig(cartoApiKey: '  ').urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(
        const MapTileConfig(cartoApiKey: 'key', forceOpenStreetMap: true)
            .usesCarto,
        false);
  });
  test('Google requires an explicit provider choice', () async {
    var calls = 0;
    final container = ProviderContainer(overrides: [
      googleMapsLoaderProvider.overrideWithValue(() async {
        calls++;
        return true;
      }),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(googleMapsReadyProvider.future), false);
    expect(calls, 0);
    final google = ProviderContainer(overrides: [
      mapProviderSelectionProvider.overrideWithValue('google'),
      googleMapsLoaderProvider.overrideWithValue(() async {
        calls++;
        return true;
      }),
    ]);
    addTearDown(google.dispose);
    expect(await google.read(googleMapsReadyProvider.future), true);
    expect(calls, 1);
  });
}
