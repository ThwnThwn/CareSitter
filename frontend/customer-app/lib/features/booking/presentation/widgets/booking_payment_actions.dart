import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'booking_detail_screen_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingPaymentActions extends StatelessWidget {
  const BookingPaymentActions({
    super.key,
    required this.onPay,
    required this.booking,
    required this.cancelButton,
  });
  final void Function() onPay;
  final BookingModel booking;
  final Widget cancelButton;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BookingDetailScreenStatusBanner(
                message:
                    'Vui lòng xem thông tin thanh toán và hoàn tiền trước khi xác nhận. Người chăm sóc sẽ được thông báo sau khi thanh toán thành công.'),
            const SizedBox(height: AppSpacing.control),
            ElevatedButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.payment_rounded),
              label: Text(
                  'Thanh toán và gửi yêu cầu (${formatVnd(booking.payableAmount, suffix: '')}đ)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.control),
            cancelButton,
          ]);
}
