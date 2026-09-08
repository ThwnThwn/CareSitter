import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_notifier.dart';
import 'core/push/firebase_push_notifications.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class CaregiverApp extends ConsumerStatefulWidget {
  const CaregiverApp({super.key});

  @override
  ConsumerState<CaregiverApp> createState() => _CaregiverAppState();
}

class _CaregiverAppState extends ConsumerState<CaregiverApp> {
  @override
  void initState() {
    super.initState();
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
      }
    });

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'CareSitter Caregiver',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
