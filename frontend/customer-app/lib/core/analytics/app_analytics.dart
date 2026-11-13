import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_event.dart';
import 'analytics_sink.dart';
export 'analytics_event.dart';

final analyticsSinkProvider =
    Provider<AnalyticsSink>((_) => NoopAnalyticsSink());
final appAnalyticsProvider = Provider<AppAnalytics>(
  (ref) => AppAnalytics(ref.watch(analyticsSinkProvider)),
);

/// Serial identity/event ordering; telemetry never blocks a business operation.
class AppAnalytics {
  AppAnalytics(this._sink, {this.timeout = const Duration(seconds: 2)});
  final AnalyticsSink _sink;
  final Duration timeout;
  Future<void> _queue = Future.value();
  int _pending = 0;
  String? _userId;
  bool _identified = false;
  bool _deliveryStopped = false;
  final Set<String> _seen = {};
  Future<void> get drained => _queue;

  void identify(String? userId) {
    if (_identified && _userId == userId) return;
    _seen.clear();
    _identified = true;
    _userId = userId;
    _enqueue(() => _sink.setUserId(userId), identity: true);
  }

  void log(AnalyticsEvent event, [Map<String, Object> parameters = const {}]) {
    if (parameters.keys.any((key) => !event.parameters.contains(key)) ||
        parameters.values.any((value) => value is! String && value is! num)) {
      throw ArgumentError('Invalid analytics schema for ${event.eventName}');
    }
    final snapshot = Map<String, Object>.unmodifiable(parameters);
    _enqueue(() => _sink.log(event, snapshot));
  }

  void logOnce(
      AnalyticsEvent event, String operation, Map<String, Object> parameters) {
    if (!_seen.add('${event.eventName}:$operation')) return;
    if (_seen.length > 256) _seen.remove(_seen.first);
    log(event, parameters);
  }

  void _enqueue(Future<void> Function() action, {bool identity = false}) {
    if (_pending >= 128 && !identity) return;
    _pending++;
    _queue = _queue.then((_) async {
      try {
        if (_deliveryStopped) return;
        await action().timeout(timeout);
      } on TimeoutException {
        _deliveryStopped = true;
        debugPrint('[Analytics] delivery paused until restart');
      } catch (_) {
        // Identity failures cannot allow later events under the previous user.
        if (identity) _deliveryStopped = true;
        debugPrint('[Analytics] delivery unavailable');
      } finally {
        _pending--;
      }
    });
  }
}
