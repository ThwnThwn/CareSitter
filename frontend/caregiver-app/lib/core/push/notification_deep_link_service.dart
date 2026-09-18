import 'dart:async';
import 'dart:collection';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/router/app_router.dart';

final notificationMessengerKey = GlobalKey<ScaffoldMessengerState>();

final notificationDeepLinkServiceProvider =
    Provider<NotificationDeepLinkService>((ref) {
  final service = NotificationDeepLinkService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class NotificationDeepLinkService {
  NotificationDeepLinkService(this._ref) {
    unawaited(_listenForNativeLinks());
  }

  final Ref _ref;
  final Set<String> _processedDeliveries = {};
  final Queue<String> _deliveryOrder = Queue<String>();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingRoute;
  bool _disposed = false;

  String? resolveRoute(Map<String, dynamic> data) {
    final bookingId = _safeId(data['bookingId']);
    final type = data['type']?.toString().trim().toUpperCase() ?? '';
    final status = data['status']?.toString().trim().toLowerCase() ?? '';
    final supplied = _normalizeSuppliedRoute(data['deepLink']);

    if (supplied != null) return supplied;
    if (bookingId == null) {
      if (type == 'PAYMENT' || type == 'PAYOUT') return '/earnings';
      if (type == 'SUPPORT') return '/settings/support';
      return type.isEmpty ? null : '/notifications';
    }

    if (type == 'SOS' || status == 'in_progress' || status == 'checked_in') {
      return '/shifts/$bookingId/active';
    }
    if (status == 'checkout_pending_review' || status == 'completed') {
      return '/shifts/$bookingId/summary';
    }
    return '/shifts/$bookingId';
  }

  Future<void> handle(
    Map<String, dynamic> data, {
    String? deliveryId,
  }) async {
    if (!_rememberDelivery(deliveryId)) return;
    final route = resolveRoute(data);
    if (route == null) return;

    final isAuthenticated =
        _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuthenticated) {
      _pendingRoute = route;
      return;
    }
    _ref.read(appRouterProvider).go(route);
  }

  Future<void> flushPending() async {
    final route = _pendingRoute;
    final isAuthenticated =
        _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (route == null || !isAuthenticated) return;
    _pendingRoute = null;
    _ref.read(appRouterProvider).go(route);
  }

  void showForeground({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? deliveryId,
  }) {
    final messenger = notificationMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(body.isEmpty ? title : '$title\n$body'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Xem',
            onPressed: () => handle(data, deliveryId: deliveryId),
          ),
        ),
      );
  }

  Future<void> _listenForNativeLinks() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (_disposed) return;
      if (initialLink != null) await _handleNativeLink(initialLink);
      if (_disposed) return;
      _linkSubscription = _appLinks.uriLinkStream.listen(_handleNativeLink);
    } catch (_) {
      // Deep links are optional on unsupported desktop/test platforms.
    }
  }

  Future<void> _handleNativeLink(Uri uri) => handle(
        {'deepLink': uri.toString()},
        deliveryId: 'uri:$uri',
      );

  void dispose() {
    _disposed = true;
    _linkSubscription?.cancel();
  }

  bool _rememberDelivery(String? deliveryId) {
    if (deliveryId == null || deliveryId.trim().isEmpty) return true;
    if (!_processedDeliveries.add(deliveryId)) return false;
    _deliveryOrder.addLast(deliveryId);
    if (_deliveryOrder.length > 128) {
      _processedDeliveries.remove(_deliveryOrder.removeFirst());
    }
    return true;
  }

  String? _normalizeSuppliedRoute(Object? value) {
    var route = value?.toString().trim();
    if (route == null || route.isEmpty) return null;

    final uri = Uri.tryParse(route);
    if (uri != null &&
        (uri.scheme == 'caresitter' || uri.scheme == 'caresitter-caregiver')) {
      route = '/${[
        uri.host,
        ...uri.pathSegments
      ].where((e) => e.isNotEmpty).join('/')}';
    }

    final bookingRoute =
        RegExp(r'^/bookings/([A-Za-z0-9-]+)$').firstMatch(route);
    if (bookingRoute != null) return '/shifts/${bookingRoute.group(1)}';

    final patterns = [
      RegExp(r'^/shifts/[A-Za-z0-9-]+$'),
      RegExp(r'^/shifts/[A-Za-z0-9-]+/(active|map|summary)$'),
      RegExp(r'^/earnings$'),
      RegExp(r'^/settings/support$'),
      RegExp(r'^/notifications$'),
    ];
    return patterns.any((pattern) => pattern.hasMatch(route!)) ? route : null;
  }
}

String? _safeId(Object? value) {
  final id = value?.toString().trim();
  if (id == null || id.isEmpty) return null;
  return RegExp(r'^[A-Za-z0-9-]+$').hasMatch(id) ? id : null;
}
