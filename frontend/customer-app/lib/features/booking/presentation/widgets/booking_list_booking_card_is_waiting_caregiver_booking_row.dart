import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_is_waiting_caregiver_booking_content.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_caregiver_avatar.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_action_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingListBookingCardIsWaitingCaregiverBookingRow
    extends StatelessWidget {
  const BookingListBookingCardIsWaitingCaregiverBookingRow(
      {super.key,
      required this.isWaitingCaregiver,
      required this.booking,
      required this.status});
  final bool isWaitingCaregiver;
  final BookingModel booking;
  final String status;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (isWaitingCaregiver)
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.warningLight,
              child:
                  Icon(Icons.auto_awesome, size: 16, color: AppColors.warning),
            )
          else
            BookingCaregiverAvatar(
              radius: 18,
              avatarUrl: booking.caregiverAvatar,
              initials: booking.caregiverInitials,
            ),
          const SizedBox(width: AppSpacing.sm),
          BookingListBookingCardIsWaitingCaregiverBookingContent(
              isWaitingCaregiver: isWaitingCaregiver, booking: booking),
          // Action buttons
          if (status == 'confirmed' ||
              status == 'caregiver_accepted' ||
              status == 'pending') ...[
            BookingListActionIconButton(
              icon: Icons.call_outlined,
              onTap: () {},
            ),
            const SizedBox(width: AppSpacing.tight),
            BookingListActionIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () {},
            ),
          ],
        ],
      );
}
