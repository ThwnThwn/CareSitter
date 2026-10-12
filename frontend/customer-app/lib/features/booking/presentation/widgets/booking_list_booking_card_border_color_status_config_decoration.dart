import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_booking_row.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_booking_row_body.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_booking_row_inner.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_border_color_content.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_fields.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_is_waiting_caregiver_booking_row.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_status_config_border_color_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

class BookingListBookingCardBorderColorStatusConfigDecoration
    extends StatelessWidget {
  const BookingListBookingCardBorderColorStatusConfigDecoration(
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
  Widget build(BuildContext context) => Stack(
        children: [
          BookingListBookingCardBorderColorContent(borderColor: borderColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.section,
                AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: Status pill + Price ──
                BookingListBookingCardStatusConfigBorderColorContent(
                    statusConfig: statusConfig,
                    borderColor: borderColor,
                    formatCurrencyFull: formatCurrencyFull,
                    booking: booking),
                const SizedBox(height: AppSpacing.compact),

                // ── Row 2: Date / Time / Address ──
                BookingListBookingCardBookingRowBody(booking: booking),
                const SizedBox(height: AppSpacing.xs),
                BookingListBookingCardBookingRow(booking: booking),
                const SizedBox(height: AppSpacing.xs),
                BookingListBookingCardBookingRowInner(booking: booking),

                const SizedBox(height: AppSpacing.compact),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.control),

                // ── Row 3: Caregiver ──
                BookingListBookingCardIsWaitingCaregiverBookingRow(
                    isWaitingCaregiver: isWaitingCaregiver,
                    booking: booking,
                    status: status),

                // ── Review button ──
                if (status == 'completed' && !booking.isReviewed)
                  BookingListBookingCardFields(
                      callbackAction1: callbackAction2),
              ],
            ),
          ),
        ],
      );
}
