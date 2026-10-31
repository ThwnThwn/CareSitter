import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

typedef NotificationVisual = ({
  IconData icon,
  Color background,
  Color foreground,
});

NotificationVisual notificationVisualFor(String type, {String? status}) {
  final normalizedType = type.trim().toUpperCase();
  final normalizedStatus = status?.trim().toUpperCase();
  if (normalizedType == 'BOOKING') {
    return switch (normalizedStatus) {
      'CAREGIVER_EN_ROUTE' => (
          icon: Icons.directions_walk_rounded,
          background: AppColors.infoLight,
          foreground: AppColors.info,
        ),
      'IN_PROGRESS' => (
          icon: Icons.play_circle_outline_rounded,
          background: AppColors.primaryContainer,
          foreground: AppColors.primary,
        ),
      'CHECKOUT_PENDING_REVIEW' => (
          icon: Icons.fact_check_outlined,
          background: AppColors.warningLight,
          foreground: AppColors.warning,
        ),
      'COMPLETED' => (
          icon: Icons.task_alt_rounded,
          background: AppColors.primaryContainer,
          foreground: AppColors.primary,
        ),
      'CANCELLED' => (
          icon: Icons.event_busy_outlined,
          background: AppColors.surfaceVariant,
          foreground: AppColors.textSecondary,
        ),
      'CONFIRMED' || 'CAREGIVER_ACCEPTED' => (
          icon: Icons.event_available_outlined,
          background: AppColors.primaryContainer,
          foreground: AppColors.primary,
        ),
      _ => (
          icon: Icons.event_note_rounded,
          background: AppColors.primaryContainer,
          foreground: AppColors.primary,
        ),
    };
  }
  if (normalizedType == 'PAYMENT' && normalizedStatus == 'REFUNDED') {
    return (
      icon: Icons.currency_exchange_rounded,
      background: AppColors.infoLight,
      foreground: AppColors.info,
    );
  }
  return switch (normalizedType) {
    'BOOKING_CHAT' => (
        icon: Icons.chat_bubble_outline_rounded,
        background: AppColors.primaryContainer,
        foreground: AppColors.primary,
      ),
    'SUPPORT_CHAT' => (
        icon: Icons.support_agent_rounded,
        background: AppColors.infoLight,
        foreground: AppColors.info,
      ),
    'BOOKING_OFFER' => (
        icon: Icons.event_available_outlined,
        background: AppColors.primaryContainer,
        foreground: AppColors.primary,
      ),
    'MATCHING_FAILED' => (
        icon: Icons.person_off_outlined,
        background: AppColors.warningLight,
        foreground: AppColors.warning,
      ),
    'SHIFT' => (
        icon: Icons.work_outline_rounded,
        background: AppColors.primaryContainer,
        foreground: AppColors.primary,
      ),
    'CARE_TIMELINE' => (
        icon: Icons.timeline_rounded,
        background: AppColors.infoLight,
        foreground: AppColors.info,
      ),
    'PAYMENT' => (
        icon: Icons.payments_outlined,
        background: AppColors.infoLight,
        foreground: AppColors.info,
      ),
    'PAYOUT' => (
        icon: Icons.account_balance_wallet_outlined,
        background: AppColors.primaryContainer,
        foreground: AppColors.primary,
      ),
    'REVIEW' || 'CHECKOUT_REVIEW' => (
        icon: Icons.rate_review_outlined,
        background: AppColors.warningLight,
        foreground: AppColors.warning,
      ),
    'KYC' => (
        icon: Icons.verified_user_outlined,
        background: AppColors.infoLight,
        foreground: AppColors.info,
      ),
    'SOS' || 'CRISIS' => (
        icon: Icons.sos_rounded,
        background: AppColors.errorLight,
        foreground: AppColors.error,
      ),
    _ => (
        icon: Icons.notifications_none_rounded,
        background: AppColors.surfaceVariant,
        foreground: AppColors.textSecondary,
      ),
  };
}
