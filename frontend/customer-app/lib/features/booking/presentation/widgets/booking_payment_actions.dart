import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingPaymentActions extends StatelessWidget {
  const BookingPaymentActions(
      {super.key,
      required this.buildStatusBanner,
      required this.action2,
      required this.formatCurrency,
      required this.booking,
      required this.buildCancelButton,
      required this.ref});
  final Widget Function(String) buildStatusBanner;
  final void Function() action2;
  final String Function(double) formatCurrency;
  final BookingModel booking;
  final Widget Function(BuildContext, WidgetRef, BookingModel)
      buildCancelButton;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildStatusBanner(
                'Đơn đang chờ bạn thanh toán ký quỹ (Escrow) để kích hoạt và thông báo cho người chăm sóc.'),
            const SizedBox(height: AppSpacing.control),
            ElevatedButton.icon(
              onPressed: action2,
              icon: const Icon(Icons.payment_rounded),
              label: Text(
                  'Thanh toán ký quỹ (${formatCurrency(booking.totalPrice)}đ)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.control),
            buildCancelButton(context, ref, booking),
          ]);
}
