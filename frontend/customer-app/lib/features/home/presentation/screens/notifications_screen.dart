import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/notifications_controller.dart';
import '../widgets/notification_inbox_list.dart';
import '../widgets/notification_inbox_loading.dart';
import '../widgets/notifications_app_bar.dart';
import '../widgets/notifications_notification_load_error.dart';

export '../widgets/notifications_presentation_helpers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markingAll = false;
  bool _loadingMore = false;

  NotificationsNotifier get _inbox => ref.read(notificationsProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const NotificationsAppBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: inbox.when(
              skipLoadingOnRefresh: false,
              loading: () => const NotificationInboxLoading(),
              error: (_, __) =>
                  NotificationsNotificationLoadError(onRetry: _inbox.refresh),
              data: (snapshot) => NotificationInboxList(
                snapshot: snapshot,
                onRefresh: _inbox.refresh,
                onMarkAll: _markingAll ? null : _markAll,
                onLoadMore: _loadingMore ? null : _loadMore,
                onOpen: _open,
                onMarkRead: _markRead,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markAll() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await _inbox.markAllRead();
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Chưa thể đánh dấu đã đọc. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      await _inbox.loadMore();
    } catch (_) {
      if (mounted) AppToast.error(context, 'Chưa thể tải thông báo cũ hơn.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markRead(AppNotification item) async {
    try {
      await _inbox.markRead(item.id);
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Chưa thể đánh dấu đã đọc. Vui lòng thử lại.');
      }
    }
  }

  Future<void> _open(AppNotification item) async {
    final userId = ref.read(authStateProvider).valueOrNull?.userId;
    await _markRead(item);
    if (!mounted || userId != ref.read(authStateProvider).valueOrNull?.userId) {
      return;
    }
    final links = ref.read(notificationDeepLinkServiceProvider);
    final data = {
      ...item.data,
      'type': item.type,
    };
    final route = links.resolveRoute(data);
    if (route != null && route != AppRoutes.notifications) {
      await links.handle(data);
    }
  }
}
