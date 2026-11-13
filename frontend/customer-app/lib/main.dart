import 'core/push/push_permission_action.dart';
import 'core/push/push_messaging_gateway.dart';
import 'core/push/firebase_push_messaging_gateway.dart';
import 'core/runtime_config/runtime_config_service.dart';
import 'core/runtime_config/firebase_runtime_config_service.dart';
import 'core/diagnostics/crash_reporter.dart';
import 'core/diagnostics/firebase_crash_reporter.dart';
import 'app/diagnostics/crash_error_hooks.dart';
import 'package:caresitter_customer/core/analytics/app_analytics.dart';
import 'package:caresitter_customer/core/analytics/firebase_analytics_sink.dart';
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
  final crashReporter = await FirebaseCrashReporter.initialize();
  installCrashErrorHooks(crashReporter);
  runApp(ProviderScope(overrides: [
    pushPermissionActionProvider.overrideWith((ref) => () => ref
        .read(pushNotificationServiceProvider)
        .syncTokenForCurrentUser(requestPermission: true)),
    pushMessagingGatewayProvider
        .overrideWithValue(FirebasePushMessagingGateway()),
    crashReporterProvider.overrideWithValue(crashReporter),
    runtimeConfigServiceProvider
        .overrideWithValue(FirebaseRuntimeConfigService()),
    analyticsSinkProvider.overrideWithValue(FirebaseAnalyticsSink()),
    notificationDeepLinkServiceProvider
        .overrideWith(createNotificationDeepLinkService),
  ], child: const CareSitterApp()));
}
