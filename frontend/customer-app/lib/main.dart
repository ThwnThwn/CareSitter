import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/app/push/notification_deep_link_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/app/care_sitter_app.dart';
import 'package:caresitter_customer/app/push/firebase_push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Đăng ký background handler trước khi runApp.
  // Phải là top-level function — gọi khi app terminated/background nhận FCM.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebasePushNotifications.initialize();
  runApp(ProviderScope(overrides: [
    notificationDeepLinkServiceProvider
        .overrideWith(createNotificationDeepLinkService),
  ], child: const CareSitterApp()));
}
