import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/app.dart';
import 'package:caresitter_customer/core/config/env_config.dart';
import 'package:caresitter_customer/core/push/firebase_push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.initialize();
  // Đăng ký background handler trước khi runApp.
  // Phải là top-level function — gọi khi app terminated/background nhận FCM.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebasePushNotifications.initialize();
  runApp(const ProviderScope(child: CareSitterApp()));
}
