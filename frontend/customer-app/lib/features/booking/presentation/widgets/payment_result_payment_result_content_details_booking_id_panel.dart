import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_payment_result_content_booking_id_fields.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_payment_result_content_details_index_fields.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/models/payment_result_details.dart';

class PaymentResultPaymentResultContentDetailsBookingIdPanel
    extends StatelessWidget {
  const PaymentResultPaymentResultContentDetailsBookingIdPanel(
      {super.key, required this.details, required this.bookingId});
  final PaymentResultDetails details;
  final String? bookingId;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.comfortable),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            for (var index = 0; index < details.highlights.length; index++)
              PaymentResultPaymentResultContentDetailsIndexFields(
                  details: details, index: index),
            if (bookingId != null)
              PaymentResultPaymentResultContentBookingIdFields(
                  bookingId: bookingId),
          ],
        ),
      );
}
