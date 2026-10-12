import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/models/payment_result_details.dart';

class PaymentResultPaymentResultContentDetailsContent extends StatelessWidget {
  const PaymentResultPaymentResultContentDetailsContent(
      {super.key, required this.details});
  final PaymentResultDetails details;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact, vertical: AppSpacing.tight),
          decoration: BoxDecoration(
            color: details.labelBackground,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Text(
            details.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: details.labelColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
          ),
        ),
      );
}
