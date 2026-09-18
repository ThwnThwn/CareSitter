import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/home/data/models/notification_model.dart';
import 'package:caresitter_customer/features/home/data/repositories/notification_repository.dart';

export 'package:caresitter_customer/features/home/data/models/notification_model.dart';

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

/// Shared notification inbox: screens and realtime events observe one source of truth.
class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  @override
  Future<List<AppNotification>> build() {
    final isAuthenticated =
        ref.watch(authStateProvider).value?.isAuthenticated ?? false;
    return isAuthenticated ? _fetch() : Future.value(const []);
  }

  int get unreadCount => (state.valueOrNull ?? const [])
      .where((notification) => !notification.isRead)
      .length;

  Future<void> refresh() async {
    try {
      state = AsyncData(await _fetch());
    } catch (error, stackTrace) {
      // Keep a usable inbox and badge visible when a background refresh fails.
      if (!state.hasValue) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<void> markAllRead() async {
    final previous = state.valueOrNull ?? const [];
    if (previous.isEmpty ||
        previous.every((notification) => notification.isRead)) {
      return;
    }

    state = AsyncData([
      for (final notification in previous) notification.copyWith(isRead: true),
    ]);
    try {
      await _repository.markAllRead();
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> markRead(String id) async {
    if (id.isEmpty) return;
    final previous = state.valueOrNull ?? const [];
    final index = previous.indexWhere((notification) => notification.id == id);
    if (index < 0 || previous[index].isRead) return;

    state = AsyncData([
      for (final notification in previous)
        notification.id == id
            ? notification.copyWith(isRead: true)
            : notification,
    ]);
    try {
      await _repository.markRead(id);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<List<AppNotification>> _fetch() => _repository.getNotifications();
}
