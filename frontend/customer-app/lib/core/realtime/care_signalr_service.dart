import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../auth/auth_notifier.dart';

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

/// Mô tả một event GPS nhận từ backend.
class GpsUpdate {
  final String bookingId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;

  const GpsUpdate({
    required this.bookingId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.speed,
    this.heading,
    required this.recordedAt,
  });

  factory GpsUpdate.fromJson(Map<String, dynamic> json) => GpsUpdate(
        bookingId: json['bookingId'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
        speed: (json['speed'] as num?)?.toDouble(),
        heading: (json['heading'] as num?)?.toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );
}

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
        bookingId: json['bookingId'] as String,
        oldStatus: json['oldStatus'] as String,
        newStatus: json['newStatus'] as String,
        changedAt: DateTime.parse(json['changedAt'] as String),
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
        bookingId: json['bookingId'] as String,
        eventType: json['eventType'] as String,
        title: json['title'] as String?,
        note: json['note'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );
}

/// Quản lý kết nối SignalR với CareTrackingHub trên backend.
///
/// Sử dụng:
///   final signalR = ref.read(careSignalRProvider);
///   await signalR.joinBooking(bookingId);
///   signalR.gpsStream.listen(...);     // nhận GPS updates
///   signalR.statusStream.listen(...);  // nhận status changes
class CareSignalRService {
  final Ref _ref;
  HubConnection? _connection;

  // Stream controllers
  final _gpsController = StreamController<GpsUpdate>.broadcast();
  final _statusController = StreamController<BookingStatusChange>.broadcast();
  final _timelineController = StreamController<TimelineEventUpdate>.broadcast();

  /// Stream GPS updates — subscribe từ tracking screen.
  Stream<GpsUpdate> get gpsStream => _gpsController.stream;

  /// Stream booking status changes — subscribe từ booking detail/tracking screen.
  Stream<BookingStatusChange> get statusStream => _statusController.stream;

  /// Stream timeline events — subscribe từ care timeline screen.
  Stream<TimelineEventUpdate> get timelineStream => _timelineController.stream;

  CareSignalRService(this._ref);

  /// Danh sách booking ID đang theo dõi — dùng để re-join sau khi reconnect.
  final Set<String> _activeBookings = {};

  bool get isConnected =>
      _connection?.state == HubConnectionState.Connected;

  /// Kết nối tới Hub và đăng ký handlers.
  /// Tự động đính kèm JWT access token vào query string.
  Future<void> connect() async {
    if (_connection != null &&
        _connection!.state == HubConnectionState.Connected) {
      return;
    }

    final token = _ref.read(authStateProvider).value?.accessToken;
    if (token == null) return; // Chưa login → không kết nối

    final hubUrl = '$_hubBaseUrl/hubs/care-tracking?access_token=$token';

    _connection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect(retryDelays: [
          2000, 5000, 10000, 30000, // ms
        ])
        .build();

    // ── Đăng ký event handlers ──────────────────────────────────────

    _connection!.on('GpsUpdated', (args) {
      if (args == null || args.isEmpty) return;
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

    _connection!.onclose(({error}) {
      // ignore: avoid_print
      print('[SignalR] Connection closed: $error');
    });

    _connection!.onreconnecting(({error}) {
      // ignore: avoid_print
      print('[SignalR] Reconnecting: $error');
    });

    _connection!.onreconnected(({connectionId}) {
      // ignore: avoid_print
      print('[SignalR] Reconnected: $connectionId — re-joining ${_activeBookings.length} groups');
      // ⚠️ ConnectionId mới → group membership bị mất.
      // Phải re-invoke JoinBookingGroup cho mỗi booking đang active.
      for (final bid in _activeBookings) {
        _connection!.invoke('JoinBookingGroup', args: [bid]).catchError((e) {
          // ignore: avoid_print
          print('[SignalR] Re-join failed for $bid: $e');
          return null;
        });
      }
    });

    try {
      await _connection!.start();
      // ignore: avoid_print
      print('[SignalR] Connected to CareTrackingHub');
    } catch (e) {
      // ignore: avoid_print
      print('[SignalR] Connection failed: $e');
    }
  }

  /// Join group theo dõi một booking cụ thể.
  /// Gọi sau khi connect() thành công.
  Future<void> joinBooking(String bookingId) async {
    await connect();
    if (!isConnected) return;
    try {
      final result = await _connection!.invoke('JoinBookingGroup', args: [bookingId]);
      if (result == 'unauthorized') {
        // ignore: avoid_print
        print('[SignalR] joinBooking UNAUTHORIZED: $bookingId');
        return;
      }
      // Lưu lại để re-join sau khi reconnect
      _activeBookings.add(bookingId);
      // ignore: avoid_print
      print('[SignalR] Joined booking group: $bookingId');
    } catch (e) {
      // ignore: avoid_print
      print('[SignalR] joinBooking error: $e');
    }
  }

  /// Rời group khi thoát màn hình tracking.
  Future<void> leaveBooking(String bookingId) async {
    _activeBookings.remove(bookingId); // Không re-join sau reconnect
    if (!isConnected) return;
    try {
      await _connection!.invoke('LeaveBookingGroup', args: [bookingId]);
    } catch (e) {
      // ignore
    }
  }

  /// Dừng kết nối và đóng stream controllers.
  Future<void> dispose() async {
    try {
      await _connection?.stop();
    } catch (_) {}
    await _gpsController.close();
    await _statusController.close();
    await _timelineController.close();
  }
}
