import 'dart:async';
import 'package:caresitter_customer/core/realtime/care_signalr_service.dart';

/// Sở hữu subscription của booking; không dừng hub dùng chung khi dispose.
class BookingRealtimeController {
  BookingRealtimeController(
      {required this.hub,
      required this.active,
      required this.sync,
      required this.refreshNotifications,
      required this.refreshChatNotifications,
      required this.reloadTasks,
      required this.onTask,
      required this.announceAccepted});
  final CareSignalRService Function() hub;
  final bool Function() active;
  final Future<void> Function() sync, refreshNotifications;
  final Future<void> Function() refreshChatNotifications;
  final void Function() reloadTasks;
  final void Function(Map<String, dynamic>) onTask;
  final void Function(String, String) announceAccepted;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _announced = {};
  Future<void>? _connecting;
  bool _closed = false;
  bool get _current => !_closed && active();
  Future<void> connect() {
    if (!_current || _subscriptions.isNotEmpty) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    try {
      final signalR = hub();
      await signalR.connect();
      if (!_current || !signalR.isConnected) return;
      _subscriptions.addAll([
        signalR.customerSyncStream.listen((_) {
          if (!_current) return;
          unawaited(sync());
          unawaited(refreshNotifications());
        }),
        signalR.statusStream.listen((event) => unawaited(_status(event))),
        signalR.onReconnected.listen((_) {
          if (!_current) return;
          unawaited(sync());
          reloadTasks();
        }),
        signalR.onTaskUpdated.listen((event) {
          if (_current) onTask(event);
        }),
        signalR.bookingChatStream.listen((_) {
          if (_current) unawaited(refreshChatNotifications());
        }),
      ]);
      unawaited(sync());
    } catch (_) {
      // Hub chưa mở được: requestSync sau sẽ thử nối lại.
    }
  }

  Future<void> _status(BookingStatusChange event) async {
    if (!_current ||
        event.bookingId.isEmpty ||
        event.newStatus.toLowerCase() != 'caregiver_accepted') {
      return;
    }
    final key =
        '${event.bookingId}:${event.newStatus}:${event.changedAt.toUtc().microsecondsSinceEpoch}';
    if (!_announced.add(key)) return;
    if (_announced.length > 128) {
      _announced
        ..clear()
        ..add(key);
    }
    await sync();
    if (!_current) return;
    await refreshNotifications();
    if (_current) announceAccepted(event.bookingId, event.newStatus);
  }

  void dispose() {
    _closed = true;
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    _announced.clear();
  }
}
