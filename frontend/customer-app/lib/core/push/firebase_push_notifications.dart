import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';
import '../auth/auth_notifier.dart';

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
  String? _lastRegisteredToken;

  PushNotificationService(this._ref);

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
  }

  Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) return;

    try {
      await _ref.read(dioClientProvider).post('/auth/devices', data: {
        'platform': _platform,
        'pushToken': token,
        'deviceName': defaultTargetPlatform.name,
      });
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
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
    unawaited(_tokenRefreshSub?.cancel());
  }
}
