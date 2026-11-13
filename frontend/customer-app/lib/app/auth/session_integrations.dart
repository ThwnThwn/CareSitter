import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/analytics/app_analytics.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/auth/data/services/firebase_identity_bridge.dart';
import 'package:caresitter_customer/features/auth/data/services/google_sign_in_gateway.dart';

final sessionIntegrationsProvider = Provider<void>((ref) {
  final auth = ref.read(authStateProvider.notifier);
  final bridge = ref.read(firebaseIdentityBridgeProvider);
  final analytics = ref.read(appAnalyticsProvider);
  Future<void> cleanup() async {
    await bridge.signOut();
    await ref.read(googleIdentityGatewayProvider).clearLocalSelection();
  }

  auth.registerLogoutCleanup(cleanup);
  ref.onDispose(() => auth.unregisterLogoutCleanup(cleanup));
  var initialReconciled = false;
  ref.listen(authStateProvider, (_, next) {
    if (!next.hasValue) return;
    final session = next.valueOrNull;
    analytics
        .identify(session?.isAuthenticated == true ? session?.userId : null);
    if (initialReconciled) return;
    initialReconciled = true;
    final generation = auth.sessionGeneration;
    unawaited(() async {
      try {
        final valid = await bridge.reconcileSession(session?.userId);
        if (!valid && auth.sessionGeneration == generation) await auth.logout();
      } catch (_) {
        // Secure storage/platform unavailable: backend guards remain authoritative.
      }
    }());
  }, fireImmediately: true);
});
