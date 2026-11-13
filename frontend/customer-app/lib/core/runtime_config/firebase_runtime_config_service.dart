import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'runtime_config.dart';
import 'runtime_config_service.dart';

class FirebaseRuntimeConfigService implements RuntimeConfigService {
  FirebaseRuntimeConfigService({FirebaseRemoteConfig? sdk})
      : _overrideSdk = sdk;
  final FirebaseRemoteConfig? _overrideSdk;
  Future<void>? _initialization;
  FirebaseRemoteConfig get _sdk =>
      _overrideSdk ?? FirebaseRemoteConfig.instance;
  bool get _ready =>
      _overrideSdk != null ||
      Firebase.apps.any((app) => app.name == '[DEFAULT]');
  Future<void> _initialize() => _initialization ??= () async {
        try {
          await _sdk.setConfigSettings(RemoteConfigSettings(
              fetchTimeout: const Duration(seconds: 10),
              minimumFetchInterval: kDebugMode
                  ? const Duration(seconds: 30)
                  : const Duration(hours: 12)));
          await _sdk.setDefaults(
              {'catalog_banner_enabled': true, 'catalog_page_size': 20});
          await _sdk.ensureInitialized();
        } catch (_) {
          _initialization = null;
          rethrow;
        }
      }();
  RuntimeConfig _read(String source) => RuntimeConfig.fromValues(
      banner: _sdk.getValue('catalog_banner_enabled').asString(),
      pageSize: _sdk.getValue('catalog_page_size').asString(),
      source: source);
  @override
  Future<RuntimeConfig> loadActivated() async {
    if (!_ready) return const RuntimeConfig();
    await _initialize();
    final remote = _sdk.getValue('catalog_banner_enabled').source ==
            ValueSource.valueRemote ||
        _sdk.getValue('catalog_page_size').source == ValueSource.valueRemote;
    return _read(remote ? 'cached' : 'defaults');
  }

  @override
  Future<RuntimeConfig> fetchAndActivate() async {
    if (!_ready) throw StateError('Firebase chưa khởi tạo.');
    await _initialize();
    await _sdk.fetchAndActivate();
    return _read('remote');
  }
}
