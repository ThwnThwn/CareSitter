import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/booking/presentation/models/payment_result_details.dart';

class PaymentResultPaymentResultContentDetailsContentBody
    extends StatelessWidget {
  const PaymentResultPaymentResultContentDetailsContentBody(
      {super.key, required this.details});
  final PaymentResultDetails details;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
              color: details.iconBackground, shape: BoxShape.circle),
          child: Icon(details.icon, size: 48, color: details.iconColor),
        ),
      );
}
