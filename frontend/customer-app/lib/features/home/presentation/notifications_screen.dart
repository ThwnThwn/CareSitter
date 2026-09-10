import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/presentation/widgets/fade_slide_staggered.dart';

class _Notification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? route;
  bool isRead;

  _Notification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route,
    this.isRead = false,
  });

  factory _Notification.fromJson(Map<String, dynamic> json) {
    final data = _decodeData(json['data']);
    return _Notification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'INFO',
      title: json['title']?.toString() ?? 'Thông báo',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      route: data['deepLink']?.toString(),
      isRead: json['readAt'] != null,
    );
  }

  static Map<String, dynamic> _decodeData(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return const {};
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<_Notification> _notifications = const [];
  bool _isLoading = true;

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadNotifications);
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioClientProvider);
      final resp = await dio.get<Map<String, dynamic>>(
        '/notifications',
        query: {'pageSize': 50},
      );
      final items = (resp.data?['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_Notification.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    final previous = _notifications;
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
    try {
      await ref.read(dioClientProvider).put<void>('/notifications/read-all');
    } catch (_) {
      if (!mounted) return;
      setState(() => _notifications = previous);
    }
  }

  Future<void> _onTap(_Notification notif) async {
    final wasRead = notif.isRead;
    setState(() => notif.isRead = true);
    if (!wasRead && notif.id.isNotEmpty) {
      try {
        await ref
            .read(dioClientProvider)
            .put<void>('/notifications/${notif.id}/read');
      } catch (_) {}
    }
    if (!mounted) return;
    if (notif.route != null) {
      context.push(notif.route!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông báo',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount chưa đọc',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Đọc tất cả',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: AppColors.divider,
                  ),
                  itemBuilder: (context, index) => FadeSlideStaggered(
                    index: index,
                    child: _buildItem(_notifications[index]),
                  ),
                ),
    );
  }

  Widget _buildItem(_Notification notif) {
    final icon = _iconFor(notif.type);
    final iconColor = _iconColorFor(notif.type);
    return InkWell(
      onTap: () => _onTap(notif),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: notif.isRead
            ? Colors.transparent
            : AppColors.primary.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _relativeTime(notif.createdAt),
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (notif.route != null)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 10),
                child: Icon(Icons.chevron_right,
                    color: AppColors.textHint, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('booking')) return Icons.event_available_outlined;
    if (normalized.contains('payment') || normalized.contains('wallet')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (normalized.contains('review')) return Icons.star_outline;
    if (normalized.contains('sos') || normalized.contains('crisis')) {
      return Icons.warning_amber_rounded;
    }
    return Icons.notifications_none_outlined;
  }

  Color _iconColorFor(String type) {
    final normalized = type.toLowerCase();
    if (normalized.contains('sos') || normalized.contains('crisis')) {
      return AppColors.error;
    }
    if (normalized.contains('payment') || normalized.contains('wallet')) {
      return const Color(0xFFE67E22);
    }
    if (normalized.contains('review')) return const Color(0xFFF39C12);
    return AppColors.primary;
  }

  String _relativeTime(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${value.day}/${value.month}/${value.year}';
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_outlined,
                color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có thông báo',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Các thông báo về lịch hẹn sẽ hiển thị ở đây',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
