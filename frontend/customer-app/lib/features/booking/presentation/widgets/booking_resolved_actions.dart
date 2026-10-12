import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingResolvedActions extends StatelessWidget {
  const BookingResolvedActions(
      {super.key,
      required this.buildStatusBanner,
      required this.status,
      required this.buildCancelButton,
      required this.ref,
      required this.booking});
  final Widget Function(String) buildStatusBanner;
  final String status;
  final Widget Function(BuildContext, WidgetRef, BookingModel)
      buildCancelButton;
  final WidgetRef ref;
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildStatusBanner(
              status == 'confirmed'
                  ? 'Lịch hẹn đã được xác nhận. Bạn sẽ nhận thông báo khi chăm sóc viên cập nhật tiến trình ca.'
                  : 'Ca đã được nhận. Vui lòng chờ caregiver bắt đầu di chuyển hoặc check-in từ ứng dụng caregiver.',
            ),
            const SizedBox(height: AppSpacing.control),
            buildCancelButton(context, ref, booking),
          ]);
}
