import 'dart:async';
import 'package:web/web.dart' as web;
import 'package:caresitter_customer/core/config/env_config.dart';

Future<bool>? _loading;

Future<bool> ensureGoogleMapsLoaded() {
  if (EnvConfig.googleMapsWebApiKey.trim().isEmpty) return Future.value(false);
  return _loading ??= _load();
}

Future<bool> _load() async {
  final script = web.HTMLScriptElement()
    ..id = 'caresitter-google-maps'
    ..async = true
    ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
      'key': EnvConfig.googleMapsWebApiKey,
      'v': 'quarterly',
      'language': 'vi',
      'region': 'VN',
    }).toString();
  final ready = Completer<bool>();
  final loaded = script.onLoad.listen((_) {
    if (!ready.isCompleted) ready.complete(true);
  });
  final failed = script.onError.listen((_) {
    if (!ready.isCompleted) ready.complete(false);
  });
  web.document.head!.append(script);
  final result = await ready.future
      .timeout(const Duration(seconds: 12), onTimeout: () => false);
  await loaded.cancel();
  await failed.cancel();
  if (!result) {
    script.remove();
    _loading = null;
  }
  return result;
}
