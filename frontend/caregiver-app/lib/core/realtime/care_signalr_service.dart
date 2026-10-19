import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';

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

/// A lightweight caregiver inbox signal. The offer itself is always refetched
/// so expiry and rank remain server-authoritative.
class BookingOfferChange {
  final String bookingId;
  final String changeType;
  final DateTime changedAt;

  const BookingOfferChange({
    required this.bookingId,
    required this.changeType,
    required this.changedAt,
  });

  factory BookingOfferChange.fromJson(Map<String, dynamic> json) =>
      BookingOfferChange(
        bookingId: json['bookingId']?.toString() ?? '',
        changeType: json['changeType']?.toString() ?? 'changed',
        changedAt: DateTime.tryParse(json['changedAt']?.toString() ?? '') ??
            DateTime.now(),
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

enum SignalRConnectionState {
  connecting,
  connected,
  reconnecting,
  reconnected,
  closed,
}

/// Quản lý kết nối SignalR cho Caregiver App.
/// Caregiver join group → nhận BookingStatusChanged và TimelineEventAdded.
class CareSignalRService {
  final Ref _ref;
  final HubConnection Function()? _connectionFactory;
  HubConnection? _connection;
  Future<void>? _connectOperation;

  final _statusController = StreamController<BookingStatusChange>.broadcast();
  final _offerController = StreamController<BookingOfferChange>.broadcast();
  final _timelineController = StreamController<TimelineEventUpdate>.broadcast();
  final _lifecycleController =
      StreamController<SignalRConnectionState>.broadcast();
  final _taskUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _bookingChatController = StreamController<String>.broadcast();

  Stream<BookingStatusChange> get statusStream => _statusController.stream;
  Stream<BookingOfferChange> get offerStream => _offerController.stream;
  Stream<TimelineEventUpdate> get timelineStream => _timelineController.stream;
  Stream<SignalRConnectionState> get lifecycleStream =>
      _lifecycleController.stream;

  /// Stream cho CareTaskUpdated — payload: { bookingId, task }
  Stream<Map<String, dynamic>> get onTaskUpdated =>
      _taskUpdateController.stream;
  Stream<String> get bookingChatStream => _bookingChatController.stream;
  Stream<void> get onReconnected => lifecycleStream
      .where((state) => state == SignalRConnectionState.reconnected)
      .map((_) {});

  CareSignalRService(this._ref, {HubConnection Function()? connectionFactory})
      : _connectionFactory = connectionFactory {
    _authNotifier = _ref.read(authStateProvider.notifier);
    _authNotifier.registerLogoutCleanup(disconnect);
  }

  late final AuthNotifier _authNotifier;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  /// Danh sách booking đang theo dõi — dùng để re-join sau khi reconnect.
  final Map<String, int> _activeBookings = {};
  final Set<String> _joinedBookings = {};

  Future<void> connect() {
    if (isConnected) return Future.value();
    return _connectOperation ??=
        _connectInternal().whenComplete(() => _connectOperation = null);
  }

  Future<void> _connectInternal() async {
    if (isConnected) return;

    final token = _ref.read(authStateProvider).value?.accessToken;
    if (token == null) return;

    if (_connection != null) {
      try {
        await _connection!.stop();
      } catch (_) {}
    }

    _connection = _connectionFactory?.call() ??
        HubConnectionBuilder()
            .withUrl(
          '$_hubBaseUrl/hubs/care-tracking',
          options: HttpConnectionOptions(
            accessTokenFactory: () async =>
                _ref.read(authStateProvider).value?.accessToken ?? '',
          ),
        )
            .withAutomaticReconnect(
                retryDelays: [1000, 2000, 5000, 10000, 30000]).build();

    _connection!.on('BookingStatusChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _statusController.add(BookingStatusChange.fromJson(data));
      } catch (_) {}
    });

    _connection!.on('BookingOfferChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _offerController.add(BookingOfferChange.fromJson(data));
      } catch (_) {}
    });

    _connection!.on('TimelineEventAdded', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _timelineController.add(TimelineEventUpdate.fromJson(data));
      } catch (_) {}
    });

    _connection!.on('CareTaskUpdated', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        _taskUpdateController.add(data);
      } catch (_) {}
    });

    _connection!.on('BookingChatChanged', (args) {
      if (args == null || args.isEmpty) return;
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        final bookingId = data['bookingId']?.toString();
        if (bookingId != null && bookingId.isNotEmpty) {
          _bookingChatController.add(bookingId);
        }
      } catch (_) {}
    });

    _connection!.onclose(({error}) {
      _joinedBookings.clear();
      debugPrint('[SignalR-Caregiver] Connection closed.');
      _lifecycleController.add(SignalRConnectionState.closed);
    });

    _connection!.onreconnecting(({error}) {
      _joinedBookings.clear();
      debugPrint('[SignalR-Caregiver] Reconnecting.');
      _lifecycleController.add(SignalRConnectionState.reconnecting);
    });

    _connection!.onreconnected(({connectionId}) {
      debugPrint(
          '[SignalR-Caregiver] Reconnected — re-joining ${_activeBookings.length} groups');
      _joinedBookings.clear();
      for (final bid in _activeBookings.keys) {
        _connection!.invoke('JoinBookingGroup', args: [bid]).then((result) {
          if (result == 'ok' && _activeBookings.containsKey(bid)) {
            _joinedBookings.add(bid);
          }
        }).catchError((_) {
          debugPrint('[SignalR-Caregiver] Re-join failed for $bid.');
          return null;
        });
      }
      _lifecycleController.add(SignalRConnectionState.reconnected);
    });

    _lifecycleController.add(SignalRConnectionState.connecting);
    try {
      await _connection!.start();
      debugPrint('[SignalR-Caregiver] Connected');
      _lifecycleController.add(SignalRConnectionState.connected);
    } catch (_) {
      // SignalR exceptions can include the full URL with access_token. Never
      // write it to terminal logs or crash reports.
      debugPrint('[SignalR-Caregiver] Connection failed; retry will continue.');
      _lifecycleController.add(SignalRConnectionState.closed);
    }
  }

  Future<void> joinBooking(String bookingId) async {
    _activeBookings.update(bookingId, (count) => count + 1, ifAbsent: () => 1);
    await connect();
    if (!isConnected || _joinedBookings.contains(bookingId)) return;
    try {
      final result =
          await _connection!.invoke('JoinBookingGroup', args: [bookingId]);
      if (result == 'unauthorized') {
        debugPrint('[SignalR-Caregiver] joinBooking UNAUTHORIZED: $bookingId');
        _activeBookings.remove(bookingId);
        return;
      }
      if (result == 'ok') _joinedBookings.add(bookingId);
    } catch (_) {
      debugPrint('[SignalR-Caregiver] Could not join booking group.');
    }
  }

  Future<void> leaveBooking(String bookingId) async {
    final count = _activeBookings[bookingId] ?? 0;
    if (count > 1) {
      _activeBookings[bookingId] = count - 1;
      return;
    }
    _activeBookings.remove(bookingId);
    final joined = _joinedBookings.remove(bookingId);
    if (!isConnected || !joined) return;
    try {
      await _connection!.invoke('LeaveBookingGroup', args: [bookingId]);
    } catch (_) {}
  }

  Future<void> disconnect() async {
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

  Future<void> dispose() async {
    _authNotifier.unregisterLogoutCleanup(disconnect);
    await disconnect();
    await _statusController.close();
    await _offerController.close();
    await _timelineController.close();
    await _lifecycleController.close();
    await _taskUpdateController.close();
    await _bookingChatController.close();
  }
}
