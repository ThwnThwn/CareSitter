import 'dart:async';

import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

const _hubBaseUrl = String.fromEnvironment('HUB_BASE_URL',
    defaultValue: 'http://localhost:5033');

/// SignalR listener cho sự kiện BookingChatChanged từ CareTrackingHub.
class BookingChatRealtime {
  BookingChatRealtime(this._ref);
  final Ref _ref;
  final _changes = StreamController<void>.broadcast();
  HubConnection? _connection;
  Future<void>? _connecting;
  String? _joinedBookingId;
  bool _disposed = false;
  int _generation = 0;

  Stream<void> get changes => _changes.stream;

  Future<void> connect(String bookingId) async {
    if (_disposed ||
        _ref.read(authStateProvider).valueOrNull?.accessToken == null) {
      return;
    }
    if (_connection?.state == HubConnectionState.Connected &&
        _joinedBookingId == bookingId) {
      return;
    }
    if (_connecting != null) return _connecting!;
    _connecting =
        _connect(bookingId).whenComplete(() => _connecting = null);
    return _connecting;
  }

  Future<void> _connect(String bookingId) async {
    final generation = ++_generation;
    await _stopCurrent();
    if (_disposed || generation != _generation) return;

    final connection = HubConnectionBuilder()
        .withUrl(
          '$_hubBaseUrl/hubs/care-tracking',
          options: HttpConnectionOptions(
              accessTokenFactory: () async =>
                  _ref.read(authStateProvider).valueOrNull?.accessToken ?? ''),
        )
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
        .build();
    _connection = connection;

    connection.on('BookingChatChanged', (_) {
      if (!_disposed) _changes.add(null);
    });
    connection.on('BookingListSync', (_) {
      if (!_disposed) _changes.add(null);
    });

    connection.onreconnected(({connectionId}) {
      if (_disposed || generation != _generation ||
          !identical(_connection, connection)) return;
      unawaited(_join(connection, bookingId).then((_) {
        if (!_disposed) _changes.add(null);
      }).catchError((_) {}));
    });
    connection.onclose(({error}) {
      if (!_disposed && identical(_connection, connection)) {
        _joinedBookingId = null;
        _changes.add(null);
      }
    });

    try {
      await connection.start();
      if (_disposed || generation != _generation ||
          !identical(_connection, connection)) {
        unawaited(connection.stop());
        return;
      }
      await _join(connection, bookingId);
      _changes.add(null);
    } catch (_) {
      if (identical(_connection, connection)) {
        _connection = null;
        _joinedBookingId = null;
        unawaited(connection.stop());
      }
    }
  }

  Future<void> _join(HubConnection connection, String bookingId) async {
    await connection.invoke('JoinBooking', args: [bookingId]);
    _joinedBookingId = bookingId;
  }

  Future<void> disconnect() async {
    _generation++;
    await _stopCurrent();
  }

  Future<void> _stopCurrent() async {
    final previous = _connection;
    _connection = null;
    _joinedBookingId = null;
    if (previous != null) {
      try {
        await previous.stop();
      } catch (_) {}
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    unawaited(_changes.close());
  }
}
