import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/mock/mock_data.dart';

class NotificationsNotifier extends StateNotifier<List<MockNotification>> {
  NotificationsNotifier() : super([]) {
    _init();
  }

  void _init() {
    state = List.from(MockData.notifications);
  }

  int get unreadCount => state.where((n) => !n.isRead).length;

  void markAllAsRead() {
    state = [
      for (final n in state)
        MockNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          time: n.time,
          type: n.type,
          isRead: true,
        )
    ];
  }

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id)
          MockNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            time: n.time,
            type: n.type,
            isRead: true,
          )
        else
          n
    ];
  }

  void addNotification({
    required String title,
    required String body,
    required String type,
  }) {
    final newNotif = MockNotification(
      id: 'n_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      time: 'Vừa xong',
      type: type,
      isRead: false,
    );
    state = [newNotif, ...state];
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<MockNotification>>((ref) {
  return NotificationsNotifier();
});
