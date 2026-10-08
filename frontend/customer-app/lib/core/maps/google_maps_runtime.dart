import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_tile_config.dart';
import 'google_maps_runtime_stub.dart'
    if (dart.library.js_interop) 'google_maps_runtime_web.dart' as runtime;

// Chỉ tải SDK web khi mở bản đồ, không trì hoãn đăng nhập/khởi động app.
final googleMapsLoaderProvider =
    Provider<Future<bool> Function()>((ref) => runtime.ensureGoogleMapsLoaded);

final googleMapsReadyProvider = FutureProvider<bool>((ref) {
  if (ref.watch(mapProviderSelectionProvider) != 'google') return false;
  return ref.read(googleMapsLoaderProvider)();
});
