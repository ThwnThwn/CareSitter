import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/booking_controller.dart';
import '../models/booking_status_presentation.dart';
import 'booking_card_status_header.dart';
import 'booking_list_booking_card_border_color_content.dart';
import 'booking_list_booking_card_booking_row_body.dart';
import 'booking_list_booking_card_booking_row.dart';
import 'booking_list_booking_card_booking_row_inner.dart';
import 'booking_list_booking_card_is_waiting_caregiver_booking_row.dart';
import 'booking_list_booking_card_fields.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = booking.presentationStatusAt(now);
    final appearance = BookingStatusPresentation.forBooking(booking, now: now);
    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Stack(children: [
          BookingListBookingCardBorderColorContent(borderColor: appearance.color),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.section, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BookingCardStatusHeader(statusConfig: appearance, booking: booking),
              const SizedBox(height: AppSpacing.compact),
              BookingListBookingCardBookingRowBody(booking: booking),
              const SizedBox(height: AppSpacing.xs),
              BookingListBookingCardBookingRow(booking: booking),
              const SizedBox(height: AppSpacing.xs),
              BookingListBookingCardBookingRowInner(booking: booking),
              const SizedBox(height: AppSpacing.compact),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: AppSpacing.control),
              BookingListBookingCardIsWaitingCaregiverBookingRow(
                  isWaitingCaregiver: appearance.isWaitingCaregiver,
                  booking: booking,
                  status: status),
              if (status == 'completed' && !booking.isReviewed)
                BookingListBookingCardFields(
                    callbackAction1: () =>
                        context.push('/bookings/${booking.id}/review')),
            ]),
          ),
        ]),
      ),
    );
  }
}
