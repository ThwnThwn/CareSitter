import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/realtime/booking_list_sync_signal.dart';
import 'gps_update.dart';
export 'gps_update.dart';

/// URL của SignalR Hub trên backend.
/// Phải là URL gốc (không có /api/v1) vì Hub nằm ở /hubs/care-tracking.
const String _hubBaseUrl = String.fromEnvironment(
  'HUB_BASE_URL',
  defaultValue: 'http://localhost:5033',
);

/// Provider toàn cục cho CareSignalRService.
/// Singleton — tái dùng kết nối giữa các màn hình.
final careSignalRProvider = Provider<CareSignalRService>((ref) {
  final service = CareSignalRService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Mô tả sự thay đổi trạng thái booking nhận từ backend.
class BookingStatusChange {
  final String bookingId;
  final String oldStatus;
  final String newStatus;
  final DateTime changedAt;

  const BookingStatusChange({
    required this.bookingId,
    required this.oldStatus,
    required this.newStatus,
    required this.changedAt,
  });

  factory BookingStatusChange.fromJson(Map<String, dynamic> json) =>
      BookingStatusChange(
        bookingId: _string(json['bookingId']) ?? '',
        oldStatus: _string(json['oldStatus']) ?? '',
        newStatus: _string(json['newStatus']) ?? '',
        changedAt: DateTime.tryParse(json['changedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Mô tả một timeline event mới từ backend.
class TimelineEventUpdate {
  final String bookingId;
  final String eventType;
  final String? title;
  final String? note;
  final double? latitude;
  final double? longitude;
  final DateTime recordedAt;

  const TimelineEventUpdate({
    required this.bookingId,
    required this.eventType,
    this.title,
    this.note,
    this.latitude,
    this.longitude,
    required this.recordedAt,
  });

  factory TimelineEventUpdate.fromJson(Map<String, dynamic> json) =>
      TimelineEventUpdate(
        bookingId: _string(json['bookingId']) ?? '',
        eventType: _string(json['eventType']) ?? '',
        title: _string(json['title']),
        note: _string(json['note']),
        latitude: _nullableDouble(json['latitude']),
        longitude: _nullableDouble(json['longitude']),
        recordedAt: DateTime.tryParse(json['recordedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Trạng thái lifecycle của SignalR connection.
enum SignalRConnectionState {
  connecting,
  connected,
  reconnecting,
  reconnected,
  closed,
}

/// Quản lý kết nối SignalR với CareTrackingHub trên backend.
///
/// Sử dụng:
///   final signalR = ref.read(careSignalRProvider);
///   await signalR.joinBooking(bookingId);
///   signalR.gpsStream.listen(...);          // nhận GPS updates
///   signalR.statusStream.listen(...);       // nhận status changes
///   signalR.customerSyncStream.listen(...); // nhận BookingListSync trigger
///   signalR.onReconnected.listen(...);      // khi reconnect thành công
class CareSignalRService {
  final Ref _ref;
  final HubConnection Function()? _connectionFactory;
  HubConnection? _connection;
  Future<void>? _connectOperation;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  int _generation = 0;
  bool _disposed = false;
  bool _hasConnected = false;

  // Stream controllers
  final _gpsController = StreamController<GpsUpdate>.broadcast();
  final _statusController = StreamController<BookingStatusChange>.broadcast();
  final _timelineController = StreamController<TimelineEventUpdate>.broadcast();
  final _taskUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Lifecycle stream — theo dõi trạng thái kết nối SignalR.
  final _lifecycleController =
      StreamController<SignalRConnectionState>.broadcast();

  /// Stream SignalR event 'BookingListSync' — chỉ là tín hiệu kích hoạt sync,
  /// không chứa full state. Backend join customer group tự động qua OnConnectedAsync.
  final _customerSyncController =
      StreamController<BookingListSyncSignal>.broadcast();

  /// Stream GPS updates — subscribe từ tracking screen.
  Stream<GpsUpdate> get gpsStream => _gpsController.stream;

  /// Stream booking status changes — subscribe từ booking detail/tracking screen.
  Stream<BookingStatusChange> get statusStream => _statusController.stream;

  /// Stream timeline events — subscribe từ care timeline screen.
  Stream<TimelineEventUpdate> get timelineStream => _timelineController.stream;

  /// Stream cho CareTaskUpdated — payload: { bookingId, task }
  Stream<Map<String, dynamic>> get onTaskUpdated =>
      _taskUpdateController.stream;

  /// Stream trạng thái lifecycle (connecting / connected / reconnecting / ...).
  Stream<SignalRConnectionState> get lifecycleStream =>
      _lifecycleController.stream;

  /// Stream shortcut: chỉ emit khi SignalR reconnect thành công.
  /// BookingStore subscribe để trigger delta sync sau gián đoạn mạng.
  Stream<void> get onReconnected => lifecycleStream
      .where((s) => s == SignalRConnectionState.reconnected)
      .map((_) {});

  /// Stream 'BookingListSync' event từ customer group — dùng để trigger requestSync().
  Stream<BookingListSyncSignal> get customerSyncStream =>
      _customerSyncController.stream;

  CareSignalRService(this._ref, {HubConnection Function()? connectionFactory})
      : _connectionFactory = connectionFactory {
    _authNotifier = _ref.read(authStateProvider.notifier);
    _authNotifier.registerLogoutCleanup(disconnect);
  }

  late final AuthNotifier _authNotifier;

  /// Danh sách booking ID đang theo dõi — dùng để re-join sau khi reconnect.
  final Map<String, int> _activeBookings = {};
  final Set<String> _joinedBookings = {};
  bool _groupsReady = false;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;
  bool get isReady => isConnected && _groupsReady;

  /// Kết nối tới Hub và đăng ký handlers.
  /// Tự động đính kèm JWT access token vào query string.
  Future<void> connect() {
    if (_disposed || _connection?.state == HubConnectionState.Reconnecting) {
      return Future.value();
    }
    if (isConnected) return Future.value();
    return _connectOperation ??=
        _connectInternal().whenComplete(() => _connectOperation = null);
  }

  Future<void> _connectInternal() async {
    if (isConnected) return;
    final generation = _generation;

    final token = _ref.read(authStateProvider).value?.accessToken;
    if (token == null) return; // Chưa login → không kết nối

    final previous = _connection;
    _connection = null;
    if (previous != null) {
      try {
        await previous.stop();
      } catch (_) {}
    }
    if (_disposed || generation != _generation) return;

    _connection = _connectionFactory?.call() ??
        HubConnectionBuilder()
            .withUrl(
          '$_hubBaseUrl/hubs/care-tracking',
          options: HttpConnectionOptions(
            accessTokenFactory: () async =>
                _ref.read(authStateProvider).value?.accessToken ?? '',
          ),
        )
            .withAutomaticReconnect(retryDelays: [
          2000, 5000, 10000, 30000, // ms
        ]).build();
    final connection = _connection!;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        identical(_connection, connection);

    // ── Đăng ký event handlers ──────────────────────────────────────

    _connection!.on('GpsUpdated', (args) {
      if (!current() || args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _gpsController.add(GpsUpdate.fromJson(data));
      } catch (e) {
        // ignore parse error
      }
    });

    _connection!.on('BookingStatusChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _statusController.add(BookingStatusChange.fromJson(data));
      } catch (e) {
        // ignore
      }
    });

    _connection!.on('TimelineEventAdded', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _timelineController.add(TimelineEventUpdate.fromJson(data));
      } catch (e) {
        // ignore
      }
    });

    // ── Handler BookingListSync (customer scope) ────────────────────────────
    _connection!.on('BookingListSync', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _customerSyncController.add(BookingListSyncSignal.fromJson(data));
      } catch (e) {
        // ignore parse error
      }
    });

    _connection!.on('CareTaskUpdated', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _taskUpdateController.add(data);
      } catch (_) {}
    });

    _connection!.onclose(({error}) {
      if (!current()) return;
      _groupsReady = false;
      _joinedBookings.clear();
      debugPrint('[SignalR] Connection closed.');
      _lifecycleController.add(SignalRConnectionState.closed);
      _scheduleRetry();
    });

    _connection!.onreconnecting(({error}) {
      if (!current()) return;
      _groupsReady = false;
      _joinedBookings.clear();
      debugPrint('[SignalR] Reconnecting.');
      _lifecycleController.add(SignalRConnectionState.reconnecting);
    });

    _connection!.onreconnected(({connectionId}) async {
      if (!current()) return;
      debugPrint(
          '[SignalR] Reconnected: $connectionId — re-joining ${_activeBookings.length} groups');
      // ⚠️ ConnectionId mới → booking group membership bị mất.
      // Customer group được backend tự join lại qua OnConnectedAsync khi reconnect.
      // Chỉ cần re-join booking groups (tracking chi tiết).
      await _rejoinBookings(connection);
      if (current() && _groupsReady) {
        _lifecycleController.add(SignalRConnectionState.reconnected);
      }
    });

    _lifecycleController.add(SignalRConnectionState.connecting);
    try {
      await connection.start();
      if (!current()) {
        await connection.stop();
        return;
      }
      _retryAttempt = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      await _rejoinBookings(connection);
      if (!current()) return;
      debugPrint('[SignalR] Connected to CareTrackingHub');
      if (_groupsReady) {
        _lifecycleController.add(_hasConnected
            ? SignalRConnectionState.reconnected
            : SignalRConnectionState.connected);
      }
      _hasConnected = true;
    } catch (_) {
      if (!current()) return;
      // SignalR errors may contain the full negotiation URL with access_token.
      debugPrint('[SignalR] Connection failed; retry will continue.');
      _lifecycleController.add(SignalRConnectionState.closed);
      _scheduleRetry();
    }
  }

  /// Join group theo dõi một booking cụ thể.
  /// Gọi sau khi connect() thành công.
  Future<void> joinBooking(String bookingId) async {
    _activeBookings.update(bookingId, (count) => count + 1, ifAbsent: () => 1);
    await connect();
    if (!isConnected) return;
    await _rejoinBookings(_connection!);
  }

  /// Rời group khi thoát màn hình tracking.
  Future<void> leaveBooking(String bookingId) async {
    final count = _activeBookings[bookingId] ?? 0;
    if (count > 1) {
      _activeBookings[bookingId] = count - 1;
      return;
    }
    _activeBookings.remove(bookingId); // Không re-join sau reconnect
    _joinedBookings.remove(bookingId);
    if (!isConnected) return;
    try {
      await _connection!.invoke('LeaveBookingGroup', args: [bookingId]);
    } catch (e) {
      // ignore
    }
  }

  Future<void> disconnect() async {
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _hasConnected = false;
    _groupsReady = false;
    _activeBookings.clear();
    _joinedBookings.clear();
    final connection = _connection;
    _connection = null;
    try {
      await connection?.stop();
    } catch (_) {}
    if (!_lifecycleController.isClosed) {
      _lifecycleController.add(SignalRConnectionState.closed);
    }
  }

  /// Dừng kết nối và đóng stream controllers.
  Future<void> dispose() async {
    _disposed = true;
    _authNotifier.unregisterLogoutCleanup(disconnect);
    await disconnect();
    await _gpsController.close();
    await _statusController.close();
    await _timelineController.close();
    await _lifecycleController.close();
    await _customerSyncController.close();
    await _taskUpdateController.close();
  }

  Future<void> _rejoinBookings(HubConnection connection) async {
    var success = true;
    for (final id in _activeBookings.keys.toList()) {
      if (_joinedBookings.contains(id)) continue;
      try {
        final result = await connection.invoke('JoinBookingGroup', args: [id]);
        if (!identical(connection, _connection) || _disposed) return;
        if (!_activeBookings.containsKey(id)) {
          await connection.invoke('LeaveBookingGroup', args: [id]);
        } else if (result == 'ok') {
          _joinedBookings.add(id);
        } else {
          success = false;
        }
      } catch (_) {
        success = false;
      }
    }
    if (!identical(connection, _connection) || _disposed) return;
    _groupsReady = success;
    if (!success) _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed ||
        _retryTimer != null ||
        _ref.read(authStateProvider).value?.accessToken == null) {
      return;
    }
    final seconds = [2, 5, 10, 30][_retryAttempt.clamp(0, 3)];
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: seconds), () async {
      _retryTimer = null;
      if (_disposed) return;
      if (isConnected) {
        await _rejoinBookings(_connection!);
        if (!_disposed && isReady) {
          _lifecycleController.add(SignalRConnectionState.reconnected);
        }
      } else {
        await connect();
      }
    });
  }
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
