import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'runtime_config_service.dart';
import 'runtime_config_state.dart';
export 'runtime_config_state.dart';

final runtimeConfigControllerProvider =
    NotifierProvider<RuntimeConfigController, RuntimeConfigState>(
        RuntimeConfigController.new);

class RuntimeConfigController extends Notifier<RuntimeConfigState> {
  bool _active = true;
  bool _busy = false;
  @override
  RuntimeConfigState build() {
    _active = true;
    ref.onDispose(() => _active = false);
    unawaited(Future.microtask(refresh));
    return const RuntimeConfigState();
  }

  Future<void> refresh() async {
    if (!_active || _busy) return;
    _busy = true;
    final service = ref.read(runtimeConfigServiceProvider);
    state = RuntimeConfigState(
        config: state.config,
        fetching: true,
        lastActivatedAt: state.lastActivatedAt);
    try {
      final cached = await service.loadActivated();
      if (!_active) return;
      state = RuntimeConfigState(
          config: cached,
          fetching: true,
          lastActivatedAt: state.lastActivatedAt);
      final activated = await service.fetchAndActivate();
      if (!_active) return;
      state = RuntimeConfigState(
          config: activated, lastActivatedAt: DateTime.now().toUtc());
    } catch (_) {
      if (_active) {
        state = RuntimeConfigState(
            config: state.config,
            lastActivatedAt: state.lastActivatedAt,
            error:
                'Chưa tải được cấu hình mới. Đang dùng giá trị đã lưu hoặc mặc định.');
      }
    } finally {
      _busy = false;
    }
  }
}
