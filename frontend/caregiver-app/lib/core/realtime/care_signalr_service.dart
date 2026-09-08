import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../auth/auth_notifier.dart';

const String _hubBaseUrl = String.fromEnvironment(
  'HUB_BASE_URL',
  defaultValue: 'http://localhost:5033',
);

/// Provider toàn cục cho CareSignalRService (Caregiver App).
final careSignalRProvider = Provider<CareSignalRService>((ref) {
  final service = CareSignalRService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// GPS update từ server (chỉ dùng nếu admin/customer cũng broadcast lại — hiện
/// Caregiver App chủ yếu cần BookingStatusChanged để cập nhật trạng thái ca).
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

/// Timeline event mới từ server (ví dụ LATE_CHECKIN từ Hangfire job).
class TimelineEventUpdate {
  final String bookingId;
  final String eventType;
  final String? title;
  final String? note;
  final DateTime recordedAt;

  const TimelineEventUpdate({
    required this.bookingId,
    required this.eventType,
    this.title,
    this.note,
    required this.recordedAt,
  });

  factory TimelineEventUpdate.fromJson(Map<String, dynamic> json) =>
      TimelineEventUpdate(
        bookingId: json['bookingId'] as String,
        eventType: json['eventType'] as String,
        title: json['title'] as String?,
        note: json['note'] as String?,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );
}

/// Quản lý kết nối SignalR cho Caregiver App.
/// Caregiver join group → nhận BookingStatusChanged và TimelineEventAdded.
class CareSignalRService {
  final Ref _ref;
  HubConnection? _connection;

  final _statusController = StreamController<BookingStatusChange>.broadcast();
  final _timelineController = StreamController<TimelineEventUpdate>.broadcast();

  Stream<BookingStatusChange> get statusStream => _statusController.stream;
  Stream<TimelineEventUpdate> get timelineStream => _timelineController.stream;

  CareSignalRService(this._ref);

  bool get isConnected =>
      _connection?.state == HubConnectionState.Connected;

  /// Danh sách booking đang theo dõi — dùng để re-join sau khi reconnect.
  final Set<String> _activeBookings = {};

  Future<void> connect() async {
    if (_connection != null &&
        _connection!.state == HubConnectionState.Connected) {
      return;
    }

    final token = _ref.read(authStateProvider).value?.accessToken;
    if (token == null) return;

    final hubUrl = '$_hubBaseUrl/hubs/care-tracking?access_token=$token';

    _connection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
        .build();

    _connection!.on('BookingStatusChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _statusController.add(BookingStatusChange.fromJson(data));
      } catch (_) {}
    });

    _connection!.on('TimelineEventAdded', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _timelineController.add(TimelineEventUpdate.fromJson(data));
      } catch (_) {}
    });

    _connection!.onreconnected(({connectionId}) {
      // ignore: avoid_print
      print('[SignalR-Caregiver] Reconnected — re-joining ${_activeBookings.length} groups');
      for (final bid in _activeBookings) {
        _connection!.invoke('JoinBookingGroup', args: [bid]).catchError((e) {
          print('[SignalR-Caregiver] Re-join failed for $bid: $e');
          return null;
        });
      }
    });

    try {
      await _connection!.start();
      // ignore: avoid_print
      print('[SignalR-Caregiver] Connected');
    } catch (e) {
      // ignore: avoid_print
      print('[SignalR-Caregiver] Connection failed: $e');
    }
  }

  Future<void> joinBooking(String bookingId) async {
    await connect();
    if (!isConnected) return;
    try {
      final result = await _connection!.invoke('JoinBookingGroup', args: [bookingId]);
      if (result == 'unauthorized') {
        // ignore: avoid_print
        print('[SignalR-Caregiver] joinBooking UNAUTHORIZED: $bookingId');
        return;
      }
      _activeBookings.add(bookingId);
    } catch (e) {
      // ignore: avoid_print
      print('[SignalR-Caregiver] joinBooking error: $e');
    }
  }

  Future<void> leaveBooking(String bookingId) async {
    _activeBookings.remove(bookingId);
    if (!isConnected) return;
    try {
      await _connection!.invoke('LeaveBookingGroup', args: [bookingId]);
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _connection?.stop();
    } catch (_) {}
    await _statusController.close();
    await _timelineController.close();
  }
}
