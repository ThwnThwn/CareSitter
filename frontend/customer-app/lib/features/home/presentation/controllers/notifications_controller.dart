import 'dart:math' as math;

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/notifications/in_app_notification_events.dart';
import 'package:caresitter_customer/core/push/push_receipt_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_inbox_model.dart';
import '../../data/repositories/notification_inbox_pager.dart';
import '../../data/repositories/notification_repository.dart';

export '../../data/models/notification_model.dart';
export '../../data/models/notification_inbox_model.dart';

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationInboxModel>(
  NotificationsNotifier.new,
);

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final inbox = ref.watch(notificationsProvider);
  return inbox.isLoading ? 0 : inbox.valueOrNull?.unreadCount ?? 0;
});

class NotificationsNotifier extends AsyncNotifier<NotificationInboxModel> {
  NotificationRepository get _repository =>
      ref.read(notificationRepositoryProvider);

  late NotificationInboxPager _pager;
  int _revision = 0;
  String? _owner;
  Future<void> _operations = Future.value();

  @override
  Future<NotificationInboxModel> build() {
    final auth = ref.watch(authStateProvider.select(
        (s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
    _owner = auth.$2 == true ? auth.$1 : null;
    _revision++;
    _operations = Future.value();
    final owner = _owner;
    if (owner == null) return Future.value(const NotificationInboxModel());
    final pager = NotificationInboxPager(
        _repository, ref.read(pushReceiptStoreProvider), owner);
    _pager = pager;
    ref.onDispose(() {
      _revision++;
      pager.close();
    });
    final initial = pager.load();
    // Riverpod publishes the initial result before queued refreshes and writes run.
    _operations =
        initial.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return initial;
  }

  Future<void> refresh() => _schedule(_refresh);

  Future<void> loadMore() => _schedule((owner, revision) async {
        final current = state.valueOrNull;
        if (current == null || !current.hasMore) return;
        final next = await _pager.load(current: current, more: true);
        if (revision == _revision) state = AsyncData(next);
      });

  Future<void> refreshForNewChat() => _schedule((owner, revision) async {
        final previous = state.valueOrNull;
        final knownIds = previous?.items.map((item) => item.id).toSet();
        await _refresh(owner, revision);
        final current = state.valueOrNull;
        if (current == null || knownIds == null || revision != _revision) {
          return;
        }
        for (final item in current.items.reversed) {
          if (item.id.isEmpty ||
              knownIds.contains(item.id) ||
              item.isRead ||
              !item.isChat) {
            continue;
          }
          final sender = item.chat?.senderName;
          ref
              .read(inAppNotificationEventsProvider)
              .publish(InAppNotificationEvent(
                title: 'Bạn có 1 tin nhắn mới',
                body: sender != null
                    ? 'Từ $sender'
                    : item.isBookingChat
                        ? 'Tin nhắn về lịch chăm sóc'
                        : 'Phản hồi từ CareSitter',
                data: {'type': item.type, ...item.data},
                deduplicationKey: 'notification:${item.id}',
              ));
        }
      });

  Future<void> markAllRead() => _schedule((owner, revision) async {
        final current = state.valueOrNull;
        if (current == null || current.unreadCount == 0) return;
        final receipts = ref.read(pushReceiptStoreProvider);
        await _repository.markAllRead();
        if (revision != _revision) return;

        final readLocal = <String>{};
        try {
          for (final item
              in current.items.where((n) => n.isLocal && !n.isRead)) {
            await receipts.markRead(owner, item.id);
            if (revision != _revision) return;
            readLocal.add(item.id);
          }
        } finally {
          if (revision == _revision) {
            final updated = [
              for (final item in current.items)
                !item.isLocal || readLocal.contains(item.id)
                    ? item.markRead()
                    : item,
            ];
            state = AsyncData(current.copyWith(
              items: updated,
              unreadCount:
                  updated.where((item) => item.isLocal && !item.isRead).length,
            ));
          }
        }
      });

  Future<void> markRead(String id) => _schedule((owner, revision) async {
        final current = state.valueOrNull;
        if (current == null || id.isEmpty) return;
        final index = current.items.indexWhere((item) => item.id == id);
        if (index < 0 || current.items[index].isRead) return;

        final target = current.items[index];
        if (target.isLocal) {
          await ref.read(pushReceiptStoreProvider).markRead(owner, id);
        } else {
          await _repository.markRead(id);
        }
        if (revision != _revision) return;
        final items = current.items.toList()..[index] = target.markRead();
        state = AsyncData(current.copyWith(
          items: items,
          unreadCount: math.max(0, current.unreadCount - target.unreadCount),
        ));
      });

  Future<void> _refresh(String owner, int revision) async {
    try {
      final inbox = await _pager.load(current: state.valueOrNull);
      if (revision == _revision) state = AsyncData(inbox);
    } catch (error, stackTrace) {
      if (revision == _revision && !state.hasValue) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<void> _schedule(Future<void> Function(String, int) operation) {
    final owner = _owner;
    if (owner == null) return Future.value();
    final revision = _revision;
    // Keep late refreshes from replacing a completed read operation.
    final next = _operations.then((_) async {
      if (revision == _revision) await operation(owner, revision);
    });
    _operations =
        next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
}
