import 'package:flutter/material.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';

/// Nhãn, màu và tiến trình dùng chung cho danh sách và chi tiết lịch hẹn.
class BookingStatusPresentation {
  final String label;
  final Color color;
  final Color backgroundColor;
  final int currentStep;
  final bool isWaitingCaregiver;

  const BookingStatusPresentation({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.currentStep,
    this.isWaitingCaregiver = false,
  });

  factory BookingStatusPresentation.forBooking(
    BookingModel booking, {
    required DateTime now,
  }) {
    final status = booking.presentationStatusAt(now);
    if (status == 'confirmed' && booking.caregiverId == null) {
      return const BookingStatusPresentation(
        label: 'Chờ ghép CSV',
        color: AppColors.warning,
        backgroundColor: AppColors.warningLight,
        currentStep: 1,
        isWaitingCaregiver: true,
      );
    }

    switch (status) {
      case 'in_progress':
        return const BookingStatusPresentation(
          label: 'Đang diễn ra',
          color: AppColors.primary,
          backgroundColor: AppColors.primaryContainer,
          currentStep: 2,
        );
      case 'caregiver_en_route':
        return const BookingStatusPresentation(
          label: 'Đang đến',
          color: Color(0xFF0284C7),
          backgroundColor: Color(0xFFE0F2FE),
          currentStep: 2,
        );
      case 'caregiver_accepted':
      case 'assigned':
        return const BookingStatusPresentation(
          label: 'Đã nhận ca',
          color: Color(0xFF2980B9),
          backgroundColor: Color(0xFFEBF5FB),
          currentStep: 1,
        );
      case 'checkout_pending_review':
        return const BookingStatusPresentation(
          label: 'Chờ xác nhận',
          color: Color(0xFF8E44AD),
          backgroundColor: Color(0xFFF4ECF7),
          currentStep: 2,
        );
      case 'disputed':
        return const BookingStatusPresentation(
          label: 'Đang xử lý',
          color: AppColors.warning,
          backgroundColor: AppColors.warningLight,
          currentStep: 2,
        );
      case 'confirmed':
        return const BookingStatusPresentation(
          label: 'Đã xác nhận',
          color: AppColors.primary,
          backgroundColor: AppColors.primaryContainer,
          currentStep: 1,
        );
      case 'pending':
      case 'pending_payment':
        return const BookingStatusPresentation(
          label: 'Chờ thanh toán',
          color: AppColors.secondary,
          backgroundColor: AppColors.warningLight,
          currentStep: 0,
        );
      case 'payment_reconciliation_pending':
        return const BookingStatusPresentation(
          label: 'Đang đối soát',
          color: Color(0xFF0369A1),
          backgroundColor: Color(0xFFE0F2FE),
          currentStep: 0,
        );
      case 'needs_manual_review':
        return const BookingStatusPresentation(
          label: 'Chờ kiểm tra',
          color: AppColors.warning,
          backgroundColor: AppColors.warningLight,
          currentStep: 0,
        );
      case 'draft':
        return const BookingStatusPresentation(
          label: 'Bản nháp',
          color: AppColors.textHint,
          backgroundColor: AppColors.background,
          currentStep: 0,
        );
      case 'completed':
        return const BookingStatusPresentation(
          label: 'Hoàn thành',
          color: AppColors.textSecondary,
          backgroundColor: AppColors.surface,
          currentStep: 3,
        );
      case 'cancelled':
        return const BookingStatusPresentation(
          label: 'Đã huỷ',
          color: Color(0xFFE74C3C),
          backgroundColor: Color(0xFFFDEDEC),
          currentStep: -1,
        );
      case 'refunded':
        return const BookingStatusPresentation(
          label: 'Đã hoàn tiền',
          color: Color(0xFFE74C3C),
          backgroundColor: Color(0xFFFDEDEC),
          currentStep: -1,
        );
      case 'crisis':
        return const BookingStatusPresentation(
          label: 'Khẩn cấp',
          color: AppColors.error,
          backgroundColor: AppColors.errorLight,
          currentStep: 2,
        );
      case 'matching_failed':
        return const BookingStatusPresentation(
          label: 'Chưa ghép được',
          color: AppColors.warning,
          backgroundColor: AppColors.warningLight,
          currentStep: 1,
        );
      default:
        final formattedLabel = status.replaceAll('_', ' ');
        return BookingStatusPresentation(
          label: formattedLabel.isEmpty
              ? 'Chi tiết ca'
              : formattedLabel[0].toUpperCase() + formattedLabel.substring(1),
          color: AppColors.textSecondary,
          backgroundColor: AppColors.surface,
          currentStep: 1,
        );
    }
  }
}
