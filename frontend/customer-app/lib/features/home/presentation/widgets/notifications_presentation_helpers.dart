import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

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

String notificationsRelativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return '${value.day}/${value.month}/${value.year}';
}
