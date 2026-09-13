import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_notifier.dart';
import 'core/push/firebase_push_notifications.dart';
import 'core/push/notification_deep_link_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/booking/application/booking_sync_watchdog.dart';

class CareSitterApp extends ConsumerStatefulWidget {
  const CareSitterApp({super.key});

  @override
  ConsumerState<CareSitterApp> createState() => _CareSitterAppState();
}

class _CareSitterAppState extends ConsumerState<CareSitterApp> {
  @override
  void initState() {
    super.initState();
    ref.read(notificationDeepLinkServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
          ref.read(pushNotificationServiceProvider).syncTokenForCurrentUser());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      final isAuthenticated = next.value?.isAuthenticated ?? false;
      if (isAuthenticated) {
        unawaited(ref
            .read(pushNotificationServiceProvider)
            .syncTokenForCurrentUser());
        unawaited(ref.read(notificationDeepLinkServiceProvider).flushPending());
      }
    });

    final router = ref.watch(appRouterProvider);
    // BookingSyncWatchdog bọc ngoài toàn bộ app:
    // — polling 30s khi foreground
    // — trigger requestSync ngay khi app resume
    return BookingSyncWatchdog(
      child: MaterialApp.router(
        title: 'CareSitter',
        theme: AppTheme.lightTheme,
        routerConfig: router,
        scaffoldMessengerKey: notificationMessengerKey,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
