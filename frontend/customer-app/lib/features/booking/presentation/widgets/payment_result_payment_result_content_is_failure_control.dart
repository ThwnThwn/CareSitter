import 'package:flutter/material.dart';

class PaymentResultPaymentResultContentIsFailureControl
    extends StatelessWidget {
  const PaymentResultPaymentResultContentIsFailureControl(
      {super.key, required this.onOpenBooking, required this.isFailure});
  final void Function()? onOpenBooking;
  final bool isFailure;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onOpenBooking,
          icon: Icon(isFailure
              ? Icons.refresh_rounded
              : Icons.calendar_month_outlined),
          label: const Text('Xem chi tiết lịch hẹn'),
        ),
      );
}
