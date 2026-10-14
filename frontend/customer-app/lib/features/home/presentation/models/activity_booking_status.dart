import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

({String label, Color foreground, Color background}) activityBookingStatus(
    String status) {
  switch (status.toLowerCase()) {
    case 'in_progress':
      return (
        label: 'Đang diễn ra',
        foreground: AppColors.primary,
        background: AppColors.primaryContainer,
      );
    case 'caregiver_en_route':
      return (
        label: 'Đang đến',
        foreground: AppColors.info,
        background: AppColors.infoLight,
      );
    case 'caregiver_accepted':
    case 'assigned':
      return (
        label: 'Đã nhận ca',
        foreground: AppColors.legacyInfo,
        background: AppColors.legacyInfoLight,
      );
    case 'checkout_pending_review':
      return (
        label: 'Chờ xác nhận',
        foreground: AppColors.purple,
        background: AppColors.purpleLight,
      );
    case 'disputed':
      return (
        label: 'Đang xử lý',
        foreground: AppColors.warning,
        background: AppColors.warningLight,
      );
    case 'confirmed':
      return (
        label: 'Đã xác nhận',
        foreground: AppColors.warning,
        background: AppColors.secondaryContainer,
      );
    case 'pending':
    case 'pending_payment':
    case 'draft':
      return (
        label: 'Chờ xác nhận',
        foreground: AppColors.textSecondary,
        background: AppColors.background,
      );
    case 'payment_reconciliation_pending':
      return (
        label: 'Đang đối soát',
        foreground: AppColors.blueDark,
        background: AppColors.infoLight,
      );
    case 'needs_manual_review':
      return (
        label: 'Chờ kiểm tra',
        foreground: AppColors.warning,
        background: AppColors.warningLight,
      );
    case 'completed':
      return (
        label: 'Hoàn thành',
        foreground: AppColors.legacyInfo,
        background: AppColors.legacyInfoLight,
      );
    case 'cancelled':
    case 'refunded':
      return (
        label: 'Đã huỷ',
        foreground: AppColors.legacyError,
        background: AppColors.legacyErrorLight,
      );
    case 'matching_failed':
      return (
        label: 'Chưa ghép được',
        foreground: AppColors.warning,
        background: AppColors.warningLight,
      );
    default:
      final formatted = status.replaceAll('_', ' ');
      return (
        label: formatted.isEmpty
            ? 'Chi tiết ca'
            : formatted[0].toUpperCase() + formatted.substring(1),
        foreground: AppColors.textSecondary,
        background: AppColors.surface,
      );
  }
}
