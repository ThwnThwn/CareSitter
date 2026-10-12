import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/app/push/firebase_push_notifications.dart';
import 'package:caregiver_app/core/push/notification_deep_link_service.dart';
import 'package:caregiver_app/core/realtime/care_signalr_service.dart';
import 'package:caregiver_app/app/router/app_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/home/presentation/controllers/notifications_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/live_tracking_controller.dart';

class CaregiverApp extends ConsumerStatefulWidget {
  const CaregiverApp({super.key});

  @override
  ConsumerState<CaregiverApp> createState() => _CaregiverAppState();
}

class _CaregiverAppState extends ConsumerState<CaregiverApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(notificationDeepLinkServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
          ref.read(pushNotificationServiceProvider).syncTokenForCurrentUser());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final isAuthenticated =
        ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuthenticated) return;

    unawaited(ref.read(careSignalRProvider).connect());
    unawaited(ref.read(shiftsProvider.notifier).refresh());
    unawaited(ref.read(notificationsProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liveTrackingProvider);
    ref.listen(shiftsProvider, (_, shifts) {
      for (final shift in shifts) {
        ref
            .read(liveTrackingProvider.notifier)
            .reconcileStatus(shift.id, shift.status);
      }
    });
    ref.listen(authStateProvider, (_, next) {
      final isAuthenticated = next.value?.isAuthenticated ?? false;
      if (isAuthenticated) {
        unawaited(ref
            .read(pushNotificationServiceProvider)
            .syncTokenForCurrentUser());
        unawaited(ref.read(careSignalRProvider).connect());
        unawaited(ref.read(notificationDeepLinkServiceProvider).flushPending());
      }
    });

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'CareSitter Caregiver',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      scaffoldMessengerKey: notificationMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
