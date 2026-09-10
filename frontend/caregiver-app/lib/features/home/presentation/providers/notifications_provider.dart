import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/auth/auth_notifier.dart';
import '../../data/notification_model.dart';

class NotificationsNotifier extends StateNotifier<List<AppNotificationModel>> {
  final Ref _ref;

  NotificationsNotifier(this._ref) : super([]) {
    _ref.listen(authStateProvider, (previous, next) {
      if (next.value?.isAuthenticated ?? false) {
        refresh();
      } else {
        state = const [];
      }
    });
    refresh();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;

  Future<void> refresh() async {
    final isAuth = _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) {
      state = const [];
      return;
    }
    try {
      final response =
          await _ref.read(dioClientProvider).get<Map<String, dynamic>>(
        '/notifications',
        query: {'pageSize': 50},
      );
      state = (response.data?['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AppNotificationModel.fromJson)
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('[NotificationsNotifier] refresh error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final previous = state;
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
    try {
      await _ref.read(dioClientProvider).put<void>('/notifications/read-all');
    } catch (_) {
      state = previous;
    }
  }

  Future<void> markAsRead(String id) async {
    final previous = state;
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n
    ];
    try {
      await _ref.read(dioClientProvider).put<void>('/notifications/$id/read');
    } catch (_) {
      state = previous;
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotificationModel>>(
        (ref) {
  return NotificationsNotifier(ref);
});
