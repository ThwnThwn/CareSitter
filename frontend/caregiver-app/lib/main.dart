import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/push/firebase_push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebasePushNotifications.initialize();
  runApp(const ProviderScope(child: CaregiverApp()));
}
