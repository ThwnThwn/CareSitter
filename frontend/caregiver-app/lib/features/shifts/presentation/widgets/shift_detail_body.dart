import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import '../../data/models/shift_model.dart';
import '../controllers/shift_action_policy.dart';
import '../models/shift_beneficiary_presentation.dart';
import 'shift_detail_status_banner.dart';
import 'shift_detail_earnings_card.dart';
import 'shift_detail_schedule_info.dart';
import 'shift_detail_recipient_card.dart';
import 'shift_detail_location_card.dart';
import 'shift_detail_checklist_card.dart';
import 'shift_safety_card.dart';
import 'shift_detail_offer_actions.dart';
import 'shift_detail_en_route_banner.dart';
import 'shift_detail_active_action.dart';
import 'shift_detail_completed_card.dart';
import 'shift_section_heading.dart';

class ShiftDetailBody extends StatelessWidget {
  const ShiftDetailBody({super.key, required this.booking});
  final ShiftModel booking;

  @override
  Widget build(BuildContext context) {
    final beneficiary = presentShiftBeneficiary(booking);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.compact),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShiftDetailStatusBanner(booking: booking),
        const SizedBox(height: AppSpacing.compact),
        ShiftDetailEarningsCard(booking: booking),
        const SizedBox(height: AppSpacing.compact),
        ShiftDetailScheduleInfo(booking: booking),
        const SizedBox(height: AppSpacing.md),
        const ShiftSectionHeading(title: 'Người được chăm sóc'),
        const SizedBox(height: AppSpacing.sm),
        ShiftDetailRecipientCard(booking: booking, beneficiary: beneficiary),
        const SizedBox(height: AppSpacing.md),
        const ShiftSectionHeading(title: 'Địa điểm làm việc'),
        const SizedBox(height: AppSpacing.sm),
        ShiftDetailLocationCard(booking: booking),
        const SizedBox(height: AppSpacing.md),
        const ShiftSectionHeading(title: 'Công việc cần làm'),
        const SizedBox(height: AppSpacing.sm),
        ShiftDetailChecklistCard(booking: booking, beneficiary: beneficiary),
        const SizedBox(height: AppSpacing.md),
        const ShiftSafetyCard(),
        const SizedBox(height: AppSpacing.md),
        if (booking.canAccept) ShiftDetailOfferActions(bookingId: booking.id),
        if (booking.canCheckIn) ShiftDetailEnRouteBanner(booking: booking),
        if (booking.status == 'in_progress')
          ShiftDetailActiveAction(bookingId: booking.id),
        if (booking.status == 'completed')
          ShiftDetailCompletedCard(booking: booking),
        const SizedBox(height: 80),
      ]),
    );
  }
}
