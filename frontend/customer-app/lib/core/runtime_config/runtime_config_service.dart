import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'runtime_config.dart';

final runtimeConfigServiceProvider =
    Provider<RuntimeConfigService>((_) => DefaultRuntimeConfigService());

abstract interface class RuntimeConfigService {
  Future<RuntimeConfig> loadActivated();
  Future<RuntimeConfig> fetchAndActivate();
}

class DefaultRuntimeConfigService implements RuntimeConfigService {
  @override
  Future<RuntimeConfig> loadActivated() async => const RuntimeConfig();
  @override
  Future<RuntimeConfig> fetchAndActivate() async => const RuntimeConfig();
}
