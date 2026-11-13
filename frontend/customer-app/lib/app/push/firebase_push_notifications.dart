import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/push_device_repository.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/notifications/in_app_notification_events.dart';
import 'package:caresitter_customer/core/push/firebase_push_messaging_gateway.dart';
import 'package:caresitter_customer/core/push/push_messaging_gateway.dart';
import 'package:caresitter_customer/core/push/push_message.dart';
import 'package:caresitter_customer/core/push/push_receipt_store.dart';
import 'package:caresitter_customer/core/push/push_receipt_storage.dart';
import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final gateway = FirebasePushMessagingGateway();
  if (!await gateway.initialize()) return;
  try {
    await PushReceiptStore(SecurePushReceiptStorage())
        .capture(FirebasePushMessagingGateway.message(message));
  } catch (_) {
    debugPrint('[FCM] background receipt unavailable');
  }
}

class FirebasePushNotifications {
  static Future<bool> initialize() =>
      FirebasePushMessagingGateway().initialize();
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class PushNotificationService {
  PushNotificationService(this._ref,
      {this.operationTimeout = const Duration(seconds: 10)}) {
    _auth = _ref.read(authStateProvider.notifier);
    _auth.registerLogoutCleanup(unregisterCurrentDevice);
  }
  final Ref _ref;
  final Duration operationTimeout;
  late final AuthNotifier _auth;
  PushMessagingGateway get _gateway => _ref.read(pushMessagingGatewayProvider);
  StreamSubscription<String>? _tokens;
  StreamSubscription<PushMessage>? _foreground, _opened;
  String? _registeredOwner, _registeredToken, _deviceId;
  bool _disposed = false, _permissionRequested = false, _initialHandled = false;
  Future<void> _operations = Future.value();

  Future<void> _serial(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations =
        next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  bool _current(int generation, String owner) =>
      !_disposed &&
      generation == _auth.sessionGeneration &&
      _ref.read(authStateProvider).valueOrNull?.userId == owner &&
      _ref.read(authStateProvider).valueOrNull?.isAuthenticated == true;

  Future<void> syncTokenForCurrentUser({bool requestPermission = false}) {
    final session = _ref.read(authStateProvider).valueOrNull;
    if (session?.isAuthenticated != true || session?.userId == null) {
      return Future.value();
    }
    final owner = session!.userId!;
    final generation = _auth.sessionGeneration;
    return _serial(() async {
      if (!_current(generation, owner)) return;
      try {
        if (!await _gateway.initialize().timeout(operationTimeout) ||
            !_current(generation, owner)) {
          return;
        }
        _tokens ??= _gateway.tokenRefresh.listen((token) {
          final auth = _ref.read(authStateProvider).valueOrNull;
          if (auth?.isAuthenticated == true && auth?.userId != null) {
            final owner = auth!.userId!;
            final generation = _auth.sessionGeneration;
            unawaited(_serial(() => _register(token, owner, generation)));
          }
        }, onError: (Object _) {
          debugPrint('[FCM] token refresh unavailable');
        });
        _foreground ??= _gateway.foreground
            .listen((message) => unawaited(_receive(message, opened: false)));
        _opened ??= _gateway.opened
            .listen((message) => unawaited(_receive(message, opened: true)));
        try {
          if (!_initialHandled && _current(generation, owner)) {
            final initial =
                await _gateway.initialMessage().timeout(operationTimeout);
            if (!_current(generation, owner)) return;
            _initialHandled = true;
            if (initial != null) {
              await _receive(initial, opened: true);
            }
          }
        } catch (_) {
          debugPrint('[FCM] initial message unavailable');
        }
        var permission = await _gateway.permission().timeout(operationTimeout);
        if (!_current(generation, owner)) return;
        if (requestPermission ||
            (permission == PushPermission.notDetermined &&
                !_permissionRequested)) {
          _permissionRequested = true;
          permission = await _gateway
              .permission(request: true)
              .timeout(operationTimeout);
        }
        if (!_current(generation, owner)) return;
        if (permission == PushPermission.authorized ||
            permission == PushPermission.provisional) {
          final token = await _gateway.token().timeout(operationTimeout);
          if (token != null && _current(generation, owner)) {
            await _register(token, owner, generation);
          }
        }
        if (_current(generation, owner)) {
          await _ref
              .read(notificationsProvider.notifier)
              .refresh()
              .timeout(operationTimeout);
        }
      } catch (_) {
        debugPrint('[FCM] synchronization unavailable');
      }
    });
  }

  Future<void> _register(String token, String owner, int generation) async {
    if (!_current(generation, owner) ||
        (token == _registeredToken && owner == _registeredOwner)) {
      return;
    }
    try {
      final permission = await _gateway.permission().timeout(operationTimeout);
      if (!_current(generation, owner) ||
          (permission != PushPermission.authorized &&
              permission != PushPermission.provisional)) {
        return;
      }
      final id = await _ref
          .read(pushDeviceRepositoryProvider)
          .register(
              platform: _platform,
              pushToken: token,
              deviceName: defaultTargetPlatform.name)
          .timeout(operationTimeout);
      if (!_current(generation, owner)) return;
      _deviceId = id;
      await _ref
          .read(pushReceiptStoreProvider)
          .bind(owner)
          .timeout(operationTimeout);
      if (!_current(generation, owner)) {
        await _ref
            .read(pushReceiptStoreProvider)
            .clearBinding()
            .timeout(operationTimeout);
        return;
      }
      _registeredToken = token;
      _registeredOwner = owner;
    } catch (_) {
      debugPrint('[FCM] device registration unavailable');
    }
  }

  Future<void> _receive(PushMessage message, {required bool opened}) async {
    final session = _ref.read(authStateProvider).valueOrNull;
    if (session?.isAuthenticated != true ||
        session?.userId == null ||
        _disposed) {
      return;
    }
    final owner = session!.userId!;
    final generation = _auth.sessionGeneration;
    final recipient = message.data['recipient_user_id'];
    if ((message.data['source'] == 'console_test' && recipient != owner) ||
        (recipient != null && recipient != owner)) {
      return;
    }
    try {
      try {
        await _ref
            .read(pushReceiptStoreProvider)
            .capture(message)
            .timeout(operationTimeout);
      } catch (_) {
        debugPrint('[FCM] local receipt unavailable');
      }
      if (!_current(generation, owner)) return;
      unawaited(_ref
          .read(notificationsProvider.notifier)
          .refresh()
          .timeout(operationTimeout)
          .catchError((Object _) {
        debugPrint('[FCM] inbox refresh unavailable');
      }));
      if (!_current(generation, owner)) return;
      if (opened) {
        await _ref
            .read(notificationDeepLinkServiceProvider)
            .handle(message.data, deliveryId: message.id)
            .timeout(operationTimeout);
      } else {
        // Inbox availability and booking synchronization fail independently.
        unawaited(_ref
            .read(bookingStoreProvider.notifier)
            .requestSync()
            .catchError((Object _) {}));
        _ref.read(inAppNotificationEventsProvider).publish(
            InAppNotificationEvent(
                title: message.title,
                body: message.body,
                data: message.data,
                deduplicationKey: 'fcm:${message.id}'));
      }
    } catch (_) {
      debugPrint('[FCM] receipt handling unavailable');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    // Clear local attribution immediately, even while a prior registration is finishing.
    try {
      await _ref
          .read(pushReceiptStoreProvider)
          .clearBinding()
          .timeout(operationTimeout);
    } catch (_) {
      debugPrint('[FCM] local attribution cleanup unavailable');
    }
    await _serial(() async {
      try {
        if (_deviceId != null) {
          await _ref
              .read(pushDeviceRepositoryProvider)
              .unregister(_deviceId!)
              .timeout(operationTimeout);
        }
      } catch (_) {
        debugPrint('[FCM] remote cleanup unavailable');
      } finally {
        try {
          if (await _gateway.initialize().timeout(operationTimeout)) {
            await _gateway.deleteToken().timeout(operationTimeout);
          }
        } catch (_) {}
        _registeredOwner = null;
        _registeredToken = null;
        _deviceId = null;
      }
    });
  }

  String get _platform => switch (defaultTargetPlatform) {
        TargetPlatform.android => 'ANDROID',
        TargetPlatform.iOS => 'IOS',
        _ => 'WEB'
      };
  void dispose() {
    _disposed = true;
    _auth.unregisterLogoutCleanup(unregisterCurrentDevice);
    unawaited(_tokens?.cancel());
    unawaited(_foreground?.cancel());
    unawaited(_opened?.cancel());
  }
}
