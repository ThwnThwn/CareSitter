import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/runtime_config/runtime_config.dart';
import 'package:caresitter_customer/core/runtime_config/runtime_config_controller.dart';
import 'package:caresitter_customer/core/runtime_config/runtime_config_service.dart';

class ConfigService implements RuntimeConfigService {
  RuntimeConfig cached = const RuntimeConfig();
  Completer<RuntimeConfig> fetched = Completer<RuntimeConfig>();
  @override
  Future<RuntimeConfig> loadActivated() async => cached;
  @override
  Future<RuntimeConfig> fetchAndActivate() => fetched.future;
}

void main() {
  test(
      'safe defaults and bounds do not allow remote config to remove all results',
      () {
    expect(const RuntimeConfig().catalogBannerEnabled, isTrue);
    expect(const RuntimeConfig().catalogPageSize, 20);
    expect(
        RuntimeConfig.fromValues(
                banner: 'garbage', pageSize: 'bad', source: 'test')
            .catalogPageSize,
        20);
    expect(
        RuntimeConfig.fromValues(banner: 'false', pageSize: '0', source: 'test')
            .catalogPageSize,
        1);
    expect(
        RuntimeConfig.fromValues(
                banner: 'false', pageSize: '9999', source: 'test')
            .catalogPageSize,
        50);
  });
  test('cached config stays visible after failed fetch', () async {
    final service = ConfigService()
      ..cached = const RuntimeConfig(
          catalogBannerEnabled: false, catalogPageSize: 3, source: 'cached');
    final container = ProviderContainer(
        overrides: [runtimeConfigServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    container.read(runtimeConfigControllerProvider);
    await Future<void>.delayed(Duration.zero);
    service.fetched.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    final state = container.read(runtimeConfigControllerProvider);
    expect(state.config.catalogBannerEnabled, isFalse);
    expect(state.config.catalogPageSize, 3);
    expect(state.error, isNotNull);
  });
  test(
      'activated remote values replace defaults without changing auth or booking',
      () async {
    final service = ConfigService();
    final container = ProviderContainer(
        overrides: [runtimeConfigServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    container.read(runtimeConfigControllerProvider);
    await Future<void>.delayed(Duration.zero);
    service.fetched.complete(const RuntimeConfig(
        catalogBannerEnabled: false, catalogPageSize: 2, source: 'remote'));
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(runtimeConfigControllerProvider).config.catalogPageSize,
        2);
    expect(container.read(runtimeConfigControllerProvider).fetching, isFalse);
  });
}
