import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/push/firebase_push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Đăng ký background handler trước khi runApp.
  // Phải là top-level function — gọi khi app terminated/background nhận FCM.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebasePushNotifications.initialize();
  runApp(const ProviderScope(child: CareSitterApp()));
}

