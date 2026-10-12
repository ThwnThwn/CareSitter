import 'package:caresitter_customer/features/home/presentation/widgets/activity_recent_row_booking_is_cancelled_row.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityRecentRowBookingIsCancelledInset extends StatelessWidget {
  const ActivityRecentRowBookingIsCancelledInset(
      {super.key,
      required this.booking,
      required this.isCancelled,
      required this.status,
      required this.formatCurrency,
      required this.statusConfig,
      required this.callbackAction2});
  final BookingModel booking;
  final bool isCancelled;
  final String status;
  final String Function(double) formatCurrency;
  final Map<String, dynamic> statusConfig;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.inset),
        child: ActivityRecentRowBookingIsCancelledRow(
            booking: booking,
            isCancelled: isCancelled,
            status: status,
            callbackAction2: callbackAction2,
            formatCurrency: formatCurrency,
            statusConfig: statusConfig),
      );
}
