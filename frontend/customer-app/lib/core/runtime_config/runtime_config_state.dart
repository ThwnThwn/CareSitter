import 'runtime_config.dart';

class RuntimeConfigState {
  const RuntimeConfigState(
      {this.config = const RuntimeConfig(),
      this.fetching = false,
      this.error,
      this.lastActivatedAt});
  final RuntimeConfig config;
  final bool fetching;
  final String? error;
  final DateTime? lastActivatedAt;
}
