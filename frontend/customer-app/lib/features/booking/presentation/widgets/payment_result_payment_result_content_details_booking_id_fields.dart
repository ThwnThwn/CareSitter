import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_payment_result_content_details_booking_id_panel.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_payment_result_content_details_content.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_payment_result_content_is_failure_control.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_payment_result_content_details_content_body.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/models/payment_result_details.dart';

class PaymentResultPaymentResultContentDetailsBookingIdFields
    extends StatelessWidget {
  const PaymentResultPaymentResultContentDetailsBookingIdFields(
      {super.key,
      required this.details,
      required this.bookingId,
      required this.isSyncing,
      required this.onOpenBooking,
      required this.isFailure,
      required this.refreshing,
      required this.onRetry,
      required this.onOpenBookings});
  final PaymentResultDetails details;
  final String? bookingId;
  final bool isSyncing;
  final void Function()? onOpenBooking;
  final bool isFailure;
  final bool refreshing;
  final void Function()? onRetry;
  final void Function() onOpenBookings;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaymentResultPaymentResultContentDetailsContentBody(details: details),
          const SizedBox(height: AppSpacing.lg),
          PaymentResultPaymentResultContentDetailsContent(details: details),
          const SizedBox(height: AppSpacing.md),
          Text(
            details.title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.control),
          Text(
            details.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PaymentResultPaymentResultContentDetailsBookingIdPanel(
              details: details, bookingId: bookingId),
          const SizedBox(height: AppSpacing.wide),
          if (!isSyncing)
            PaymentResultPaymentResultContentIsFailureControl(
                onOpenBooking: onOpenBooking, isFailure: isFailure)
          else if (refreshing)
            const Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5)))
          else
            SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Kiểm tra lại thanh toán'))),
          const SizedBox(height: AppSpacing.control),
          TextButton(
            onPressed: onOpenBookings,
            child: Text(isFailure
                ? 'Về danh sách lịch hẹn'
                : 'Quay lại danh sách lịch hẹn'),
          ),
        ],
      );
}
