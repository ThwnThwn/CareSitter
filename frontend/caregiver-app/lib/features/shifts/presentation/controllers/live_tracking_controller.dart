import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'dart:async';
import 'dart:math';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/shifts/data/repositories/gps_repository.dart';
import 'package:caregiver_app/features/shifts/data/repositories/tracking_location_source.dart';

final liveTrackingProvider =
    StateNotifierProvider<LiveTrackingController, LiveTrackingState>((ref) {
  final controller = LiveTrackingController(ref.read(gpsRepositoryProvider),
      ref.read(trackingLocationSourceProvider));
  final auth = ref.read(authStateProvider.notifier);
  auth.registerLogoutCleanup(controller.stop);
  ref.listen(authStateProvider, (before, after) {
    if (before?.value?.userId != after.value?.userId ||
        after.value?.isAuthenticated != true) {
      unawaited(controller.stop());
    }
  });
  ref.onDispose(() => auth.unregisterLogoutCleanup(controller.stop));
  return controller;
});

class LiveTrackingState {
  final String? bookingId;
  final String message;
  final bool sending;
  const LiveTrackingState(
      {this.bookingId, this.message = '', this.sending = false});
}

/// MVP chỉ chia sẻ khi mở app. Vào nền sẽ hủy request và dừng stream GPS.
/// Khi quay lại phải kiểm tra trạng thái trên server trước khi gửi tiếp.
class LiveTrackingController extends StateNotifier<LiveTrackingState>
    with WidgetsBindingObserver {
  LiveTrackingController(this._api, this._locations,
      {DateTime Function()? now, bool observeLifecycle = true})
      : _now = now ?? DateTime.now,
        _observeLifecycle = observeLifecycle,
        super(const LiveTrackingState()) {
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
  }

  final GpsRepository _api;
  final TrackingLocationSource _locations;
  final DateTime Function() _now;
  final bool _observeLifecycle;
  StreamSubscription<Position>? _subscription;
  Timer? _timer;
  ApiCancellation? _cancel;
  Position? _latest;
  DateTime? _lastCaptured;
  DateTime _nextSend = DateTime.fromMillisecondsSinceEpoch(0);
  String? _session;
  final String _sourceId = const Uuid().v4();
  int _generation = 0;
  int _interval = 10;
  int _failures = 0;
  bool _busy = false;
  bool _foreground = true;

  Future<void> start(String bookingId) async {
    if (!mounted || !_foreground) return;
    if (state.bookingId == bookingId && (_timer != null || _busy)) return;
    final cancelled = _cancelWork();
    final generation = _generation;
    await cancelled;
    if (!_current(generation)) return;
    _cancel = ApiCancellation();
    _busy = true;
    state = LiveTrackingState(
        bookingId: bookingId, message: 'Đang kiểm tra quyền chia sẻ vị trí…');
    try {
      if (await _api.bookingStatus(bookingId, cancelToken: _cancel) !=
          'caregiver_en_route') {
        if (_current(generation)) await stop();
        return;
      }
      if (!_current(generation)) return;
      if (!await _locations.requestAccess()) {
        if (_current(generation)) {
          state = LiveTrackingState(
              bookingId: bookingId,
              message:
                  'Chưa có quyền hoặc GPS đang tắt. Gia đình đang chờ vị trí của bạn.');
        }
        return;
      }
      if (!_current(generation)) return;
      await _openSession(bookingId, generation);
      if (!_current(generation)) return;
      state = LiveTrackingState(
          bookingId: bookingId, message: 'Đang chờ tín hiệu GPS.');
      _subscription = _locations.positions().listen((position) {
        if (!_current(generation)) return;
        _latest =
            position; // Coalesce; there is never a queue of past locations.
        unawaited(_pump(generation));
      }, onError: (_) {
        if (_current(generation)) {
          unawaited(_halt(
              'GPS bị gián đoạn. Hãy kiểm tra quyền vị trí rồi thử lại.'));
        }
      });
      _timer = Timer.periodic(
          const Duration(seconds: 1), (_) => unawaited(_pump(generation)));
    } catch (error) {
      if (_current(generation)) {
        await _halt(_errorMessage(error));
      }
    } finally {
      if (_current(generation)) _busy = false;
    }
  }

  Future<void> _openSession(String id, int generation) async {
    final result = await _api.openSession(id, _sourceId, cancelToken: _cancel);
    if (!_current(generation)) return;
    final session = result['sessionId']?.toString();
    if (session == null || session.isEmpty) {
      throw const FormatException('Missing GPS session');
    }
    _session = session;
    _interval =
        (result['sendIntervalSeconds'] as num?)?.toInt().clamp(10, 15) ?? 10;
  }

  Future<void> _pump(int generation) async {
    if (!_current(generation) || _busy || _now().isBefore(_nextSend)) return;
    final position = _latest;
    final id = state.bookingId;
    if (position == null || id == null) return;
    final age = _now().difference(position.timestamp).inSeconds;
    if (age > 60 || age < -30) {
      state = LiveTrackingState(
          bookingId: id,
          message:
              'Chưa có GPS mới hoặc đồng hồ thiết bị bị lệch. Đang chờ cập nhật.');
      return;
    }
    if (_lastCaptured != null && !position.timestamp.isAfter(_lastCaptured!)) {
      return;
    }
    _busy = true;
    try {
      if (_session == null) {
        if (await _api.bookingStatus(id, cancelToken: _cancel) !=
            'caregiver_en_route') {
          if (_current(generation)) await stop();
          return;
        }
        if (!_current(generation)) return;
        await _openSession(id, generation);
      }
      if (!_current(generation)) return;
      await _api.postLocation(id,
          sessionId: _session!,
          capturedAt: position.timestamp,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: _nonNegative(position.accuracy),
          speed: _nonNegative(position.speed),
          heading: position.heading.isFinite &&
                  position.heading >= 0 &&
                  position.heading < 360
              ? position.heading
              : null,
          cancelToken: _cancel);
      if (!_current(generation)) return;
      _lastCaptured = position.timestamp;
      _failures = 0;
      _nextSend = _now().add(Duration(
          seconds:
              position.speed >= 0 && position.speed < 0.5 ? 30 : _interval));
      state = LiveTrackingState(
          bookingId: id,
          sending: true,
          message: 'Đang chia sẻ vị trí cho ca này khi bạn mở ứng dụng.');
    } on AppApiException catch (error) {
      if (!_current(generation)) return;
      final code = error.statusCode;
      final title = error.code;
      if (code == 409 && title == 'booking.gps.invalid_session') {
        _session = null;
        _nextSend = _now().add(const Duration(seconds: 5));
      } else if (code == 401 ||
          code == 403 ||
          code == 404 ||
          code == 409 ||
          code == 410) {
        await _halt(_errorMessage(error));
      } else {
        _failures = min(_failures + 1, 5);
        final retryAfter = error.retryAfterSeconds;
        _nextSend = _now().add(Duration(
            seconds: retryAfter ?? ((1 << _failures) + Random().nextInt(4))));
        state = LiveTrackingState(
            bookingId: id,
            message: code == 400
                ? 'Mẫu GPS chưa hợp lệ. Đang chờ vị trí mới.'
                : 'Chưa gửi được vị trí. Ứng dụng sẽ thử lại.');
      }
    } catch (_) {
      if (_current(generation)) {
        _nextSend = _now().add(const Duration(seconds: 15));
        state = LiveTrackingState(
            bookingId: id, message: 'Chưa gửi được vị trí. Đang thử lại.');
      }
    } finally {
      if (_current(generation)) _busy = false;
    }
  }

  static double? _nonNegative(double value) =>
      value.isFinite && value >= 0 ? value : null;
  bool _current(int generation) =>
      mounted && generation == _generation && _foreground;

  String _errorMessage(Object error) {
    if (error is AppApiException && error.statusCode == 410) {
      return 'Chia sẻ vị trí hiện chưa được bật. Gia đình vẫn xem được trạng thái ca.';
    }
    if (error is AppApiException && error.details is Map) {
      final body = error.details! as Map;
      return body['detail']?.toString() ??
          'Phiên chia sẻ đã dừng. Hãy tải lại ca.';
    }
    return 'Chưa thể chia sẻ vị trí. Hãy kiểm tra kết nối và thử lại.';
  }

  Future<void> _halt(String message) async {
    final id = state.bookingId;
    final cancelled = _cancelWork();
    if (mounted) state = LiveTrackingState(bookingId: id, message: message);
    await cancelled;
  }

  Future<void> _cancelWork() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _cancel?.cancel('Tracking stopped');
    _cancel = null;
    final subscription = _subscription;
    _subscription = null;
    _latest = null;
    _lastCaptured = null;
    _session = null;
    _busy = false;
    _failures = 0;
    _nextSend = DateTime.fromMillisecondsSinceEpoch(0);
    await subscription?.cancel();
  }

  Future<void> stop() async {
    final cancelled = _cancelWork();
    if (mounted) state = const LiveTrackingState();
    await cancelled;
  }

  void reconcileStatus(String bookingId, String status) {
    if (state.bookingId == bookingId && status != 'caregiver_en_route') {
      unawaited(stop());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      final id = this.state.bookingId;
      if (id != null) unawaited(start(id));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      unawaited(_halt(
          'Chia sẻ vị trí tạm dừng khi ứng dụng ở nền. Mở lại để tiếp tục.'));
    }
  }

  @override
  void dispose() {
    if (_observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    unawaited(_cancelWork());
    super.dispose();
  }
}
