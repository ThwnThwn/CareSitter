import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/models/payment_result_details.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_highlight_row.dart';

class PaymentResultPaymentResultContentDetailsIndexFields
    extends StatelessWidget {
  const PaymentResultPaymentResultContentDetailsIndexFields(
      {super.key, required this.details, required this.index});
  final PaymentResultDetails details;
  final int index;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaymentResultHighlightRow(highlight: details.highlights[index]),
            if (index < details.highlights.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.inset),
                child: Divider(height: 1),
              ),
          ]);
}
