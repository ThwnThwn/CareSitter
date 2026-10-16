import 'package:caresitter_customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingDetailScreenCancelButton extends StatelessWidget {
  const BookingDetailScreenCancelButton(
      {super.key,
      required this.isCancelling,
      required this.cancelDialogOpen,
      required this.confirmCancel,
      required this.booking});
  final bool isCancelling;
  final bool cancelDialogOpen;
  final Future<void> Function(BookingModel) confirmCancel;
  final BookingModel booking;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isCancelling || cancelDialogOpen
          ? null
          : () => confirmCancel(booking),
      icon: isCancelling
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cancel_outlined, color: AppColors.error),
      label: Text(isCancelling ? 'Đang hủy...' : 'Hủy lịch hẹn'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppColors.error),
      ),
    );
  }
}
