import 'package:caresitter_customer/features/booking/presentation/widgets/booking_caregiver_contact_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_caregiver_identity.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingCaregiverContent extends StatelessWidget {
  const BookingCaregiverContent(
      {super.key,
      required this.avatarUrl,
      required this.booking,
      required this.caregiverName,
      required this.callbackAction1,
      required this.callbackAction2});
  final String? avatarUrl;
  final BookingModel booking;
  final String caregiverName;
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingCaregiverIdentity(
              avatarUrl: avatarUrl, booking: booking, caregiverName: caregiverName),
          const SizedBox(height: AppSpacing.inset),
          const Divider(height: 1, color: AppColors.background),
          const SizedBox(height: AppSpacing.compact),
          // Quick Action Buttons (matching Stitch)
          BookingCaregiverContactActions(
              callbackAction1: callbackAction1, callbackAction2: callbackAction2),
        ],
      );
}
