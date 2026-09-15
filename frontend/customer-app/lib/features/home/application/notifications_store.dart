import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/auth/auth_notifier.dart';

/// Một notification thực từ API inbox của tài khoản customer hiện tại.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.data,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'INFO',
        title: json['title']?.toString() ?? 'Thông báo',
        body: json['body']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
        data: _decodeData(json['data']),
        isRead: json['readAt'] != null,
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        data: data,
        isRead: isRead ?? this.isRead,
      );

  static Map<String, dynamic> _decodeData(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // A malformed notification payload must not hide the rest of the inbox.
      }
    }
    return const {};
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

/// Shared notification inbox: screens and realtime events observe one source of truth.
class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
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
      await ref.read(dioClientProvider).put<void>('/notifications/read-all');
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
      await ref.read(dioClientProvider).put<void>('/notifications/$id/read');
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<List<AppNotification>> _fetch() async {
    final response =
        await ref.read(dioClientProvider).get<Map<String, dynamic>>(
      '/notifications',
      query: {'pageSize': 50},
    );
    return (response.data?['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }
}
