import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/models/payment_result_highlight.dart';

class PaymentResultHighlightRow extends StatelessWidget {
  const PaymentResultHighlightRow({super.key, required this.highlight});

  final PaymentResultHighlight highlight;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(highlight.icon, color: AppColors.primaryDark, size: 21),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Text(
              highlight.text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ),
        ],
      );
}
