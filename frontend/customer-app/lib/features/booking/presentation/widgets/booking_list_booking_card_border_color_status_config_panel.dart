import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_border_color_status_config_decoration.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

class BookingListBookingCardBorderColorStatusConfigPanel
    extends StatelessWidget {
  const BookingListBookingCardBorderColorStatusConfigPanel(
      {super.key,
      required this.borderColor,
      required this.statusConfig,
      required this.formatCurrencyFull,
      required this.booking,
      required this.isWaitingCaregiver,
      required this.status,
      required this.callbackAction2});
  final Color borderColor;
  final BookingStatusPresentation statusConfig;
  final String Function(double) formatCurrencyFull;
  final BookingModel booking;
  final bool isWaitingCaregiver;
  final String status;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: BookingListBookingCardBorderColorStatusConfigDecoration(
            borderColor: borderColor,
            statusConfig: statusConfig,
            formatCurrencyFull: formatCurrencyFull,
            booking: booking,
            isWaitingCaregiver: isWaitingCaregiver,
            status: status,
            callbackAction2: callbackAction2),
      );
}
