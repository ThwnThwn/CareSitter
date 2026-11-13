import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'push_message.dart';
import 'push_messaging_gateway.dart';

class FirebasePushMessagingGateway implements PushMessagingGateway {
  @override
  Future<bool> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    try {
      if (Firebase.apps.every((app) => app.name != '[DEFAULT]')) {
        await Firebase.initializeApp();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static PushMessage message(RemoteMessage remote) => PushMessage(
      id: remote.messageId ??
          sha256
              .convert(utf8.encode(jsonEncode([
                remote.sentTime?.millisecondsSinceEpoch,
                remote.data,
                remote.notification?.title,
                remote.notification?.body
              ])))
              .toString(),
      data: Map.unmodifiable(remote.data),
      sentAt: remote.sentTime?.toUtc() ?? DateTime.now().toUtc(),
      title: remote.notification?.title ?? 'CareSitter',
      body: remote.notification?.body ?? '');
  @override
  Future<PushPermission> permission({bool request = false}) async {
    final settings = request
        ? await FirebaseMessaging.instance
            .requestPermission(alert: true, badge: true, sound: true)
        : await FirebaseMessaging.instance.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushPermission.authorized,
      AuthorizationStatus.provisional => PushPermission.provisional,
      AuthorizationStatus.denied => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };
  }

  @override
  Future<String?> token() async {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      return null;
    }
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Future<void> deleteToken() => FirebaseMessaging.instance.deleteToken();
  @override
  Stream<String> get tokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
  @override
  Stream<PushMessage> get foreground =>
      FirebaseMessaging.onMessage.map(message);
  @override
  Stream<PushMessage> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map(message);
  @override
  Future<PushMessage?> initialMessage() async {
    final remote = await FirebaseMessaging.instance.getInitialMessage();
    return remote == null ? null : message(remote);
  }
}
