import 'dart:async';
import 'package:caregiver_app/core/realtime/care_signalr_service.dart';

/// Polling/subscription thuộc danh sách ca; hub dùng chung có lifecycle riêng.
class ShiftRealtimeController {
  ShiftRealtimeController(
      {required this.hub,
      required this.active,
      required this.refresh,
      required this.reloadTasks,
      required this.onTask});
  final CareSignalRService hub;
  final bool Function() active;
  final Future<void> Function() refresh;
  final void Function() reloadTasks;
  final void Function(Map<String, dynamic>) onTask;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _timer;
  bool _closed = false;
  bool get _current => !_closed && active();
  void start() {
    if (!_current || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_current) unawaited(refresh());
    });
    unawaited(_connect());
  }

  Future<void> _connect() async {
    try {
      await hub.connect();
      if (!_current) return;
      _subscriptions.addAll([
        hub.statusStream.listen((_) {
          if (_current) unawaited(refresh());
        }),
        hub.offerStream.listen((_) {
          if (_current) unawaited(refresh());
        }),
        hub.onReconnected.listen((_) {
          if (!_current) return;
          unawaited(refresh());
          reloadTasks();
        }),
        hub.onTaskUpdated.listen((event) {
          if (_current) onTask(event);
        }),
      ]);
    } catch (_) {
      // Polling vẫn hoạt động khi hub chưa kết nối được.
    }
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
  }
}
