import 'package:caresitter_customer/features/home/presentation/widgets/activity_active_card_booking_row.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_active_card_booking_panel_body.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/activity_active_card_control.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityActiveCardBookingFields extends StatelessWidget {
  const ActivityActiveCardBookingFields(
      {super.key, required this.booking, required this.callbackAction1});
  final BookingModel booking;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ActivityActiveCardBookingRow(booking: booking),
          const SizedBox(height: AppSpacing.inset),
          // Info row
          ActivityActiveCardBookingPanelBody(booking: booking),
          const SizedBox(height: AppSpacing.compact),
          // Theo dõi button
          ActivityActiveCardControl(callbackAction1: callbackAction1),
        ],
      );
}
