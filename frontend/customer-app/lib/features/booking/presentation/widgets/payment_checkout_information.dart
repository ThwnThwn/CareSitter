import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import '../../data/models/booking_payment_summary_model.dart';
import 'booking_price_breakdown.dart';

class PaymentCheckoutInformation extends StatelessWidget {
  const PaymentCheckoutInformation({super.key, required this.summary});
  final BookingPaymentSummaryModel summary;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${formatVnd(summary.amountDue, suffix: '')} ₫',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          if (summary.discountAmount > 0 && summary.grossAmount != null) ...[
            BookingPriceBreakdown(
              grossAmount: summary.grossAmount!,
              discountAmount: summary.discountAmount,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(summary.paymentExplanation),
          const SizedBox(height: AppSpacing.sm),
          Text(summary.refundAfterPaymentIfCancelledNow == null
              ? summary.afterPaymentCancellationExplanation ??
                  'Xem điều kiện hủy và hoàn tiền bên dưới.'
              : 'Hủy trước giờ bắt đầu sau khi đã thanh toán: dự kiến hoàn ${formatVnd(summary.refundAfterPaymentIfCancelledNow!)} theo điều kiện hiện tại.'),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
            title: const Text('Chi tiết giữ tiền và hoàn tiền'),
            children: [
              Text([
                summary.settlementExplanation,
                summary.matchingExplanation,
                summary.afterPaymentCancellationExplanation ??
                    summary.cancellationExplanation
              ].join('\n\n'))
            ],
          ),
        ],
      );
}
