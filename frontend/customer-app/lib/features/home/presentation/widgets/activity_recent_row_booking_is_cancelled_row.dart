import 'package:caresitter_customer/features/home/presentation/widgets/activity_recent_row_is_cancelled_booking_content.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_recent_row_format_currency_booking_fields.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_recent_row_booking_panel.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityRecentRowBookingIsCancelledRow extends StatelessWidget {
  const ActivityRecentRowBookingIsCancelledRow(
      {super.key,
      required this.booking,
      required this.isCancelled,
      required this.status,
      required this.callbackAction2,
      required this.formatCurrency,
      required this.statusConfig});
  final BookingModel booking;
  final bool isCancelled;
  final String status;
  final void Function() callbackAction2;
  final String Function(double) formatCurrency;
  final Map<String, dynamic> statusConfig;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar icon
          ActivityRecentRowBookingPanel(booking: booking),
          const SizedBox(width: AppSpacing.inset),

          // Content
          ActivityRecentRowIsCancelledBookingContent(
              isCancelled: isCancelled,
              booking: booking,
              status: status,
              callbackAction2: callbackAction2),

          // Price + status badge
          ActivityRecentRowFormatCurrencyBookingFields(
              formatCurrency: formatCurrency,
              booking: booking,
              statusConfig: statusConfig),
        ],
      );
}
