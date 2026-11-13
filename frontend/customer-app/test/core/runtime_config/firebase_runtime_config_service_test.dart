import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/runtime_config/firebase_runtime_config_service.dart';

class ConfigSdk implements FirebaseRemoteConfig {
  int attempts = 0;
  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) async {
    if (++attempts == 1) throw StateError('temporarily unavailable');
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {}
  @override
  Future<void> ensureInitialized() async {}
  @override
  RemoteConfigValue getValue(String key) => RemoteConfigValue(
      utf8.encode(key == 'catalog_page_size' ? '2' : 'false'),
      ValueSource.valueRemote);
  @override
  Future<bool> fetchAndActivate() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('transient SDK initialization failure can recover on next refresh',
      () async {
    final sdk = ConfigSdk();
    final service = FirebaseRuntimeConfigService(sdk: sdk);
    await expectLater(service.loadActivated(), throwsStateError);
    final recovered = await service.fetchAndActivate();
    expect(sdk.attempts, 2);
    expect(recovered.catalogPageSize, 2);
    expect(recovered.catalogBannerEnabled, isFalse);
  });
}
