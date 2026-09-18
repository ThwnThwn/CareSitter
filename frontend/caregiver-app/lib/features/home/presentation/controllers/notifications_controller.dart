import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/home/data/models/notification_model.dart';
import 'package:caregiver_app/features/home/data/repositories/home_repository.dart';

class NotificationsController
    extends StateNotifier<List<AppNotificationModel>> {
  final Ref _ref;

  NotificationsController(this._ref) : super([]) {
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
      state = await _ref.read(homeRepositoryProvider).getNotifications();
    } catch (e) {
      // ignore: avoid_print
      print('[NotificationsController] refresh error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final previous = state;
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
    try {
      await _ref.read(homeRepositoryProvider).markAllNotificationsAsRead();
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
      await _ref.read(homeRepositoryProvider).markNotificationAsRead(id);
    } catch (_) {
      state = previous;
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, List<AppNotificationModel>>(
        (ref) {
  return NotificationsController(ref);
});
