import 'dart:async';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

const _hubBaseUrl = String.fromEnvironment('HUB_BASE_URL',
  defaultValue: 'http://localhost:5033');

/// The hub carries only change metadata. REST remains the source of truth.
class SupportChatRealtime {
  SupportChatRealtime(this._ref);
  final Ref _ref;
  final _changes = StreamController<void>.broadcast();
  HubConnection? _connection;
  Future<void>? _connecting;
  String? _joinedId;
  bool _disposed = false;
  int _connectionGeneration = 0;

  Stream<void> get changes => _changes.stream;

  Future<void> connect(String conversationId) async {
    if (_disposed || _ref.read(authStateProvider).valueOrNull?.accessToken == null) {
      return;
    }
    if (_connection?.state == HubConnectionState.Connected &&
        _joinedId == conversationId) {
      return;
    }
    if (_connecting != null) return _connecting!;
    _connecting = _connect(conversationId).whenComplete(() => _connecting = null);
    return _connecting;
  }

  Future<void> _connect(String conversationId) async {
    final generation = ++_connectionGeneration;
    await _stopCurrent();
    if (_disposed || generation != _connectionGeneration) return;
    final connection = HubConnectionBuilder().withUrl(
      '$_hubBaseUrl/hubs/support-chat',
      options: HttpConnectionOptions(accessTokenFactory: () async =>
        _ref.read(authStateProvider).valueOrNull?.accessToken ?? ''),
    ).withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000]).build();
    _connection = connection;
    for (final event in ['MessageCreated', 'ConversationChanged', 'ReadCursorChanged']) {
      connection.on(event, (_) {
        if (!_disposed) {
          _changes.add(null);
        }
      });
    }
    connection.onreconnected(({connectionId}) {
      if (_disposed || generation != _connectionGeneration ||
          !identical(_connection, connection)) {
        return;
      }
      unawaited(_join(connection, conversationId).then((_) {
        if (!_disposed) {
          _changes.add(null);
        }
      }).catchError((_) {}));
    });
    connection.onclose(({error}) {
      if (!_disposed && identical(_connection, connection)) {
        _joinedId = null;
        _changes.add(null);
      }
    });
    try {
      await connection.start();
      if (_disposed || generation != _connectionGeneration ||
          !identical(_connection, connection)) {
        unawaited(connection.stop());
        return;
      }
      await _join(connection, conversationId);
      _changes.add(null);
    } catch (_) {
      // The 15-second REST reconcile also retries connecting after a hub failure.
      if (identical(_connection, connection)) {
        _connection = null;
        _joinedId = null;
        unawaited(connection.stop());
      }
    }
  }

  Future<void> _join(HubConnection connection, String id) async {
    final result = await connection.invoke('JoinConversation', args: [id]);
    if (result != 'ok') throw StateError('Không được tham gia hội thoại.');
    _joinedId = id;
  }

  Future<void> disconnect() async {
    _connectionGeneration++;
    await _stopCurrent();
  }

  Future<void> _stopCurrent() async {
    final previous = _connection;
    _connection = null;
    _joinedId = null;
    if (previous != null) {
      try { await previous.stop(); } catch (_) { /* Already disconnected. */ }
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    unawaited(_changes.close());
  }
}
