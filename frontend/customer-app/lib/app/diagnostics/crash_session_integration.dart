import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/diagnostics/crash_reporter.dart';
import '../router/app_router.dart';

final crashSessionIntegrationProvider = Provider<void>((ref) {
  final reporter = ref.read(crashReporterProvider);
  void send(Future<void> action) => unawaited(action.catchError((Object _) {
        debugPrint('[Crashlytics] context unavailable');
      }));
  ref.listen(
      authStateProvider.select((s) => s.valueOrNull?.isAuthenticated == true
          ? s.valueOrNull?.userId
          : null),
      (_, userId) => send(reporter.identify(userId)),
      fireImmediately: true);
  final router = ref.read(appRouterProvider);
  void routeChanged() {
    final path = router.routeInformationProvider.value.uri.path;
    final screen = path.startsWith('/settings/lab3')
        ? 'lab3_diagnostics'
        : path.startsWith('/bookings')
            ? 'bookings'
            : path.startsWith('/catalog')
                ? 'catalog'
                : path.startsWith('/nutrition')
                    ? 'nutrition'
                    : path.startsWith('/auth')
                        ? 'auth'
                        : path.startsWith('/settings')
                            ? 'settings'
                            : 'home';
    send(reporter.setScreen(screen));
  }

  router.routeInformationProvider.addListener(routeChanged);
  ref.onDispose(
      () => router.routeInformationProvider.removeListener(routeChanged));
  routeChanged();
});
