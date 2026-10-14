import 'package:caregiver_app/core/push/notification_deep_link_service.dart';
import 'package:caregiver_app/app/push/notification_deep_link_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/app/caregiver_app.dart';
import 'package:caregiver_app/app/push/firebase_push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FirebasePushNotifications.initialize();
  runApp(ProviderScope(overrides: [
    notificationDeepLinkServiceProvider
        .overrideWith(createNotificationDeepLinkService),
  ], child: const CaregiverApp()));
}
