import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/core/push/push_receipt_store.dart';
import 'package:dio/dio.dart';

import '../models/notification_inbox_model.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

/// Loads one consistent window of server groups plus this account's device receipts.
class NotificationInboxPager {
  NotificationInboxPager(this._repository, this._receipts, this._owner);

  final NotificationRepository _repository;
  final PushReceiptStore _receipts;
  final String _owner;
  final CancelToken _cancel = CancelToken();

  void close() => _cancel.cancel();

  Future<NotificationInboxModel> load({
    NotificationInboxModel? current,
    bool more = false,
  }) async {
    final server = await _loadServer(current, more);
    _checkActive();
    final local = [
      for (final receipt in await _receipts.list(_owner))
        AppNotification(
          id: receipt.id,
          type: receipt.data['type']?.toString() ?? 'INFO',
          title: receipt.title,
          body: receipt.body,
          createdAt: receipt.sentAt.toLocal(),
          data: receipt.data,
          isRead: receipt.isRead,
          source: 'console_local',
        ),
    ];
    final items = [...server.items, ...local]..sort((a, b) {
        final order = b.timestamp.compareTo(a.timestamp);
        return order == 0 ? a.key.compareTo(b.key) : order;
      });
    return server.copyWith(
      items: items,
      unreadCount: server.unreadCount + local.where((i) => !i.isRead).length,
    );
  }

  Future<NotificationInboxModel> _loadServer(
      NotificationInboxModel? current, bool more) async {
    final visible = current?.items.where((item) => !item.isLocal) ??
        const <AppNotification>[];
    if (more && current != null && current.version != null) {
      final next = await _page(current.page + 1);
      if (next.version == current.version) {
        return next.copyWith(items: [...visible, ...next.items]);
      }
    }

    final pages = (current?.page ?? 1) + (more ? 1 : 0);
    // Follow the server's delivery order even though the UI sorts by message time.
    // This also works when the oldest previously loaded notification was removed.
    final keepTail = (current?.page ?? 1) > 1 || more;
    final oldest = keepTail && visible.isNotEmpty
        ? visible.reduce((a, b) => _deliveryOrder(a, b) <= 0 ? a : b)
        : null;
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final first = await _page(1);
      var page = first;
      final items = <String, AppNotification>{};
      final missing = {
        if (keepTail)
          for (final item in visible) item.key
      };
      while (true) {
        for (final item in page.items) {
          items[item.key] = item;
          missing.remove(item.key);
        }
        final covered = missing.isEmpty ||
            (oldest != null &&
                page.items.any((item) => _deliveryOrder(item, oldest) <= 0));
        if (!page.hasMore || (page.page >= pages && covered)) {
          return page.copyWith(items: items.values.toList());
        }

        page = await _page(page.page + 1);
        // Legacy servers have no version, but their global count is still observable.
        if (page.version != first.version ||
            page.unreadCount != first.unreadCount) {
          break;
        }
      }
    }
    throw const AppApiException(
        message: 'Thông báo vừa thay đổi. Vui lòng thử lại.');
  }

  Future<NotificationInboxModel> _page(int number) {
    _checkActive();
    return _repository.getNotifications(page: number, cancelToken: _cancel);
  }

  static int _deliveryOrder(AppNotification a, AppNotification b) {
    final order = a.createdAt.compareTo(b.createdAt);
    return order == 0 ? a.id.compareTo(b.id) : order;
  }

  void _checkActive() {
    if (_cancel.isCancelled) {
      throw const AppApiException(
          message: 'Phiên đã kết thúc.', isCancelled: true);
    }
  }
}
