import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';

import '../../data/models/notification_model.dart';

IconData notificationsIconFor(String type, {String? status}) {
  final normalizedType = type.trim().toUpperCase();
  final normalizedStatus = status?.trim().toUpperCase();
  if (normalizedType == 'BOOKING') {
    return switch (normalizedStatus) {
      'CAREGIVER_EN_ROUTE' => Icons.directions_walk_rounded,
      'IN_PROGRESS' => Icons.play_circle_outline_rounded,
      'CHECKOUT_PENDING_REVIEW' => Icons.fact_check_outlined,
      'COMPLETED' => Icons.task_alt_rounded,
      'CANCELLED' => Icons.event_busy_outlined,
      'CONFIRMED' || 'CAREGIVER_ACCEPTED' => Icons.event_available_outlined,
      _ => Icons.event_note_rounded,
    };
  }
  if (normalizedType == 'PAYMENT' && normalizedStatus == 'REFUNDED') {
    return Icons.currency_exchange_rounded;
  }
  return switch (normalizedType) {
    'BOOKING_CHAT' => Icons.chat_bubble_outline_rounded,
    'SUPPORT_CHAT' => Icons.support_agent_rounded,
    'BOOKING_OFFER' => Icons.event_available_outlined,
    'MATCHING_FAILED' => Icons.person_off_outlined,
    'SHIFT' => Icons.work_outline_rounded,
    'CARE_TIMELINE' => Icons.timeline_rounded,
    'PAYMENT' => Icons.payments_outlined,
    'PAYOUT' => Icons.account_balance_wallet_outlined,
    'REVIEW' || 'CHECKOUT_REVIEW' => Icons.rate_review_outlined,
    'KYC' => Icons.verified_user_outlined,
    'SOS' || 'CRISIS' => Icons.sos_rounded,
    _ => Icons.notifications_none_rounded,
  };
}

Color notificationsIconColorFor(String type, {String? status}) {
  final normalizedType = type.trim().toUpperCase();
  final normalizedStatus = status?.trim().toUpperCase();
  if (normalizedType == 'BOOKING') {
    return switch (normalizedStatus) {
      'CAREGIVER_EN_ROUTE' => AppColors.info,
      'CHECKOUT_PENDING_REVIEW' => AppColors.warning,
      'CANCELLED' => AppColors.textSecondary,
      _ => AppColors.primary,
    };
  }
  if (normalizedType == 'PAYMENT' && normalizedStatus == 'REFUNDED') {
    return AppColors.info;
  }
  return switch (normalizedType) {
    'SOS' || 'CRISIS' => AppColors.error,
    'MATCHING_FAILED' || 'REVIEW' || 'CHECKOUT_REVIEW' => AppColors.warning,
    'SUPPORT_CHAT' || 'CARE_TIMELINE' || 'PAYMENT' || 'KYC' => AppColors.info,
    'BOOKING_CHAT' ||
    'BOOKING_OFFER' ||
    'SHIFT' ||
    'PAYOUT' =>
      AppColors.primary,
    _ => AppColors.textSecondary,
  };
}

String notificationTimestamp(DateTime value, DateTime now) {
  final clock = formatClock(value);
  if (DateUtils.isSameDay(value, now)) return clock;
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (DateUtils.isSameDay(value, yesterday)) return '$clock hôm qua';
  final date =
      formatDate(value, padded: true, includeYear: value.year != now.year);
  return '$date · $clock';
}

Map<String, List<AppNotification>> notificationSections(
  Iterable<AppNotification> items,
  DateTime now,
) {
  final startOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 1);
  final sections = <String, List<AppNotification>>{
    'Hôm nay': [],
    'Tuần này': [],
    'Cũ hơn': [],
  };
  for (final item in items) {
    final date = item.timestamp;
    final section = DateUtils.isSameDay(date, now)
        ? 'Hôm nay'
        : date.isBefore(startOfWeek)
            ? 'Cũ hơn'
            : 'Tuần này';
    sections[section]!.add(item);
  }
  sections.removeWhere((_, items) => items.isEmpty);
  return sections;
}

String? notificationBookingLabel(AppNotification item) {
  if (!item.isBookingChat) return null;
  final start = item.chat?.scheduledStart;
  if (start != null) {
    return 'Lịch ${formatDate(start, padded: true, includeYear: false)} · ${formatClock(start)}';
  }
  final id = item.data['bookingId']?.toString().trim();
  if (id == null || id.isEmpty) return null;
  return 'Lịch #${id.substring(0, id.length.clamp(0, 8)).toUpperCase()}';
}
