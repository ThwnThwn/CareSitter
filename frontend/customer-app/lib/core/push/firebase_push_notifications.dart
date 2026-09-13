import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';
import '../auth/auth_notifier.dart';
import '../../features/booking/application/booking_store.dart';
import 'notification_deep_link_service.dart';

/// Top-level background message handler (phải là hàm top-level).
/// Gọi khi app ở background hoặc terminated và nhận FCM data message.
/// Không cần trigger BookingStore vì app sẽ sync tự động khi user mở lại app.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background: đảm bảo Firebase khởi tạo trước khi xử lý message.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  // Không cần làm gì thêm — BookingSyncWatchdog sẽ trigger requestSync khi resume.
  debugPrint('[FCM Background] type=${message.data["type"]}');
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class FirebasePushNotifications {
  static bool _initialized = false;
  static bool _initializationFailed = false;

  static Future<bool> initialize() async {
    if (_initialized) return true;
    if (_initializationFailed) return false;

    try {
      if (kIsWeb) {
        _initializationFailed = true;
        return false;
      }

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _initialized = true;
      return true;
    } catch (e) {
      _initializationFailed = true;
      debugPrint('Firebase disabled: $e');
      return false;
    }
  }
}

class PushNotificationService {
  final Ref _ref;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _openedMessageSub;
  String? _lastRegisteredToken;
  String? _registeredDeviceId;
  bool _initialMessageHandled = false;

  PushNotificationService(this._ref) {
    _authNotifier = _ref.read(authStateProvider.notifier);
    _authNotifier.registerLogoutCleanup(unregisterCurrentDevice);
  }

  late final AuthNotifier _authNotifier;

  Future<void> syncTokenForCurrentUser() async {
    final auth = _ref.read(authStateProvider).value;
    if (auth?.isAuthenticated != true) return;

    final ready = await FirebasePushNotifications.initialize();
    if (!ready) return;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    _tokenRefreshSub ??= messaging.onTokenRefresh.listen((newToken) {
      unawaited(_registerToken(newToken));
    });

    _foregroundMessageSub ??=
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _openedMessageSub ??=
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    if (!_initialMessageHandled) {
      _initialMessageHandled = true;
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleOpenedMessage(initialMessage);
      }
    }
  }

  Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) return;

    try {
      final response = await _ref
          .read(dioClientProvider)
          .post<Map<String, dynamic>>('/auth/devices', data: {
        'platform': _platform,
        'pushToken': token,
        'deviceName': defaultTargetPlatform.name,
      });
      _lastRegisteredToken = token;
      _registeredDeviceId = response.data?['id']?.toString();
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final isAuthenticated =
        _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuthenticated) return;

    await _ref.read(bookingStoreProvider.notifier).requestSync();
    final notification = message.notification;
    _ref.read(notificationDeepLinkServiceProvider).showForeground(
          title: notification?.title ?? 'CareSitter',
          body: notification?.body ?? '',
          data: Map<String, dynamic>.from(message.data),
          deliveryId: message.data['eventId']?.toString() ?? message.messageId,
        );
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) =>
      _ref.read(notificationDeepLinkServiceProvider).handle(
            Map<String, dynamic>.from(message.data),
            deliveryId:
                message.data['eventId']?.toString() ?? message.messageId,
          );

  Future<void> unregisterCurrentDevice() async {
    final deviceId = _registeredDeviceId;
    try {
      if (deviceId != null && deviceId.isNotEmpty) {
        await _ref
            .read(dioClientProvider)
            .delete<void>('/auth/devices/$deviceId');
      }
    } catch (e) {
      debugPrint('FCM device cleanup failed: $e');
    } finally {
      try {
        if (await FirebasePushNotifications.initialize()) {
          await FirebaseMessaging.instance.deleteToken();
        }
      } catch (_) {}
      _registeredDeviceId = null;
      _lastRegisteredToken = null;
    }
  }

  String get _platform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ANDROID';
      case TargetPlatform.iOS:
        return 'IOS';
      default:
        return 'WEB';
    }
  }

  void dispose() {
    _authNotifier.unregisterLogoutCleanup(unregisterCurrentDevice);
    unawaited(_tokenRefreshSub?.cancel());
    unawaited(_foregroundMessageSub?.cancel());
    unawaited(_openedMessageSub?.cancel());
  }
}
