import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/core/realtime/care_signalr_service.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'shift_tracking_state.dart';

final shiftTrackingControllerProvider = StateNotifierProvider.autoDispose
    .family<ShiftTrackingController, ShiftTrackingState, String>((ref, id) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  final store = ref.read(bookingStoreProvider.notifier);
  final controller = ShiftTrackingController(
    bookingId: id,
    signalR: ref.read(careSignalRProvider),
    readBooking: () =>
        ref.read(bookingStoreProvider).where((b) => b.id == id).firstOrNull,
    readLocation: () => store.getLatestGps(id),
    refreshBooking: store.refresh,
    reloadTasks: () => store.loadTasks(id),
  );
  ref.listen(bookingStoreProvider, (old, next) => controller.bookingChanged());
  ref.onCancel(() => controller.setVisible(false));
  ref.onResume(() => Future.microtask(() {
        if (controller.mounted) controller.setVisible(true);
      }));
  Future.microtask(controller.start);
  return controller;
});

class ShiftTrackingController extends StateNotifier<ShiftTrackingState> {
  ShiftTrackingController({
    required this.bookingId,
    required this.signalR,
    required this.readBooking,
    required this.readLocation,
    required this.refreshBooking,
    required this.reloadTasks,
  }) : super(const ShiftTrackingState());

  final String bookingId;
  final CareSignalRService signalR;
  final BookingModel? Function() readBooking;
  final Future<GpsTrackModel?> Function() readLocation;
  final Future<void> Function() refreshBooking;
  final Future<void> Function() reloadTasks;
  final _fixes = LiveGpsAccumulator();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Timer? _poll;
  Timer? _age;
  bool _foreground = true;
  bool _visible = true;
  bool _stopped = false;
  bool _loading = false;
  int _epoch = 0;
  String? _error;
  String? _caregiverId;

  Future<void> start() async {
    if (!mounted) return;
    _subscriptions.add(signalR.lifecycleStream.listen((_) => _schedule()));
    _subscriptions.add(signalR.gpsStream
        .where((e) => e.bookingId == bookingId)
        .listen(_accept));
    _subscriptions.add(signalR.statusStream
        .where((e) => e.bookingId == bookingId)
        .listen((change) {
      if (!mounted) return;
      if (change.newStatus.toLowerCase() != 'caregiver_en_route') {
        _stopped = true;
        _epoch++;
        _clear();
        _schedule();
      }
      unawaited(refreshBooking().catchError((_) {}));
    }));
    _subscriptions.add(signalR.onReconnected.listen((_) {
      if (!mounted) return;
      unawaited(reloadTasks().catchError((_) {}));
      unawaited(reload());
    }));
    _caregiverId = readBooking()?.caregiverId;
    _schedule();
    unawaited(reloadTasks().catchError((_) {}));
    // The shared service owns its connection; this flow owns only membership.
    unawaited(signalR.joinBooking(bookingId).catchError((_) {}));
    await reload();
  }

  void bookingChanged() {
    if (!mounted) return;
    final booking = readBooking();
    final stopped = booking?.status != 'caregiver_en_route';
    final changed = booking?.caregiverId != _caregiverId;
    final wasStopped = _stopped;
    _caregiverId = booking?.caregiverId;
    _stopped = stopped;
    if (stopped || changed) {
      _epoch++;
      _loading = false;
      _clear();
    }
    _schedule();
    if (!stopped && (wasStopped || changed)) unawaited(reload());
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _epoch++;
      _loading = false;
    }
    _schedule();
    if (foreground) unawaited(reload());
  }

  void setVisible(bool visible) {
    _visible = visible;
    _schedule();
    if (visible) unawaited(reload());
  }

  void _schedule() {
    _poll?.cancel();
    _age?.cancel();
    if (!mounted || !_foreground || !_visible || _stopped) return;
    _age = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _foreground && _visible) _publish();
    });
    _poll = Timer.periodic(Duration(seconds: signalR.isReady ? 30 : 10),
        (_) => unawaited(reload()));
  }

  void _accept(GpsUpdate gps) {
    if (!mounted || !_foreground || !_visible || _stopped) return;
    final booking = readBooking();
    if (booking == null ||
        !_fixes.accept(gps,
            bookingId: bookingId,
            caregiverId: booking.caregiverId,
            enRoute: booking.status == 'caregiver_en_route')) {
      return;
    }
    _error = null;
    _publish();
  }

  void _clear() {
    _fixes.clear();
    _publish();
  }

  void _publish() {
    if (!mounted) return;
    final fix = _fixes.latest;
    final age = fix == null
        ? 0
        : DateTime.now().difference(fix.recordedAt).inSeconds.clamp(0, 999999);
    final label = _stopped
        ? 'Đã dừng theo dõi di chuyển'
        : _error ??
            (fix == null
                ? 'Đang chờ vị trí'
                : age > 60
                    ? 'Vị trí cũ · ${age ~/ 60} phút trước'
                    : (fix.accuracyMeters ?? 0) > 100
                        ? 'GPS kém · $age giây trước'
                        : '${signalR.isReady ? 'Đang cập nhật' : 'Kết nối lại'} · $age giây trước');
    state = ShiftTrackingState(
        latitude: fix?.latitude,
        longitude: fix?.longitude,
        heading: fix?.heading,
        recordedAt: fix?.recordedAt,
        label: label);
  }

  Future<void> reload() async {
    if (!mounted || !_foreground || !_visible || _loading || _stopped) return;
    final booking = readBooking();
    if (booking == null || booking.status != 'caregiver_en_route') {
      _stopped = true;
      _schedule();
      _clear();
      return;
    }
    _loading = true;
    final epoch = _epoch;
    final watermark = _fixes.version;
    try {
      final latest = await readLocation();
      if (!mounted || !_foreground || epoch != _epoch || _stopped) return;
      _error = null;
      if (latest == null) {
        if (_fixes.version == watermark) _clear();
      } else {
        _accept(GpsUpdate(
            bookingId: latest.bookingId,
            caregiverId: latest.caregiverId,
            latitude: latest.latitude,
            longitude: latest.longitude,
            recordedAt: latest.recordedAt,
            version: latest.version,
            bookingVersion: latest.bookingVersion,
            sessionId: latest.sessionId,
            receivedAt: latest.receivedAt,
            accuracyMeters: latest.accuracyMeters,
            speed: latest.speed,
            heading: latest.heading));
      }
      _publish();
    } on AppApiException catch (error) {
      if (!mounted || epoch != _epoch) return;
      if (error.statusCode == 403 || error.statusCode == 410) _fixes.clear();
      _error = error.statusCode == 410
          ? 'Chia sẻ vị trí chưa được bật'
          : 'Mất kết nối · đang thử lại';
      _publish();
    } catch (_) {
      if (mounted && epoch == _epoch) {
        _error = 'Chưa tải được vị trí';
        _publish();
      }
    } finally {
      if (epoch == _epoch) _loading = false;
    }
  }

  @override
  void dispose() {
    _epoch++;
    _poll?.cancel();
    _age?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(signalR.leaveBooking(bookingId).catchError((_) {}));
    super.dispose();
  }
}
