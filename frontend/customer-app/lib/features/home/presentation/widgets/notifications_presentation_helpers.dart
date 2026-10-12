import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

IconData notificationsIconFor(String type) {
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

Color notificationsIconColorFor(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('sos') || normalized.contains('crisis')) {
    return AppColors.error;
  }
  if (normalized.contains('payment') || normalized.contains('wallet')) {
    return AppColors.warning;
  }
  if (normalized.contains('review')) return AppColors.secondary;
  return AppColors.primary;
}

String notificationsRelativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return '${value.day}/${value.month}/${value.year}';
}
