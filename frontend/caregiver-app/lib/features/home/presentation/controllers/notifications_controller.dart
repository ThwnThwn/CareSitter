import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/home/data/models/notification_model.dart';
import 'package:caregiver_app/features/home/data/repositories/home_repository.dart';

class NotificationsController
    extends StateNotifier<List<AppNotificationModel>> {
  final Ref _ref;
  int _generation = 0;
  int _revision = 0;

  NotificationsController(this._ref) : super([]) {
    refresh();
  }

  int get unreadCount => state.where((n) => !n.isRead).length;

  Future<void> refresh() async {
    if (!mounted) return;
    final generation = ++_generation;
    final isAuth = _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) {
      state = const [];
      return;
    }
    try {
      final notifications =
          await _ref.read(homeRepositoryProvider).getNotifications();
      if (!mounted || generation != _generation) return;
      _revision++;
      state = notifications;
    } catch (e) {
      // ignore: avoid_print
      print('[NotificationsController] refresh error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (!mounted) return;
    _generation++;
    final revision = ++_revision;
    final previous = state;
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
    try {
      await _ref.read(homeRepositoryProvider).markAllNotificationsAsRead();
    } catch (_) {
      if (mounted && revision == _revision) state = previous;
    }
  }

  Future<void> markAsRead(String id) async {
    if (!mounted) return;
    _generation++;
    final revision = ++_revision;
    final previous = state;
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n
    ];
    try {
      await _ref.read(homeRepositoryProvider).markNotificationAsRead(id);
    } catch (_) {
      if (mounted && revision == _revision) state = previous;
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, List<AppNotificationModel>>(
        (ref) {
  ref.watch(authStateProvider.select(
      (session) => (session.value?.userId, session.value?.isAuthenticated)));
  return NotificationsController(ref);
});
