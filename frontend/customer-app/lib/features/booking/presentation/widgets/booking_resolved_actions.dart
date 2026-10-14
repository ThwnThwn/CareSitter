import 'booking_detail_screen_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingResolvedActions extends StatelessWidget {
  const BookingResolvedActions({
    super.key,
    required this.status,
    required this.cancelButton,
  });
  final String status;
  final Widget cancelButton;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingDetailScreenStatusBanner(
              message: status == 'confirmed'
                  ? 'Lịch hẹn đã được xác nhận. Bạn sẽ nhận thông báo khi chăm sóc viên cập nhật tiến trình ca.'
                  : 'Ca đã được nhận. Vui lòng chờ caregiver bắt đầu di chuyển hoặc check-in từ ứng dụng caregiver.',
            ),
            const SizedBox(height: AppSpacing.control),
            cancelButton,
          ]);
}
