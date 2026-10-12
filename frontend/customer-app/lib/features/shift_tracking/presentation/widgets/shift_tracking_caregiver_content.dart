import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_caregiver_identity.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_caregiver_actions.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingCaregiverContent extends StatelessWidget {
  const ShiftTrackingCaregiverContent(
      {super.key,
      required this.avatarText,
      required this.bk,
      required this.statusLabel,
      required this.callbackAction1,
      required this.callbackAction2});
  final String avatarText;
  final BookingModel bk;
  final String statusLabel;
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ShiftTrackingCaregiverIdentity(
              avatarText: avatarText, bk: bk, statusLabel: statusLabel),
          const SizedBox(height: AppSpacing.control),
          const SizedBox(height: AppSpacing.inset),
          ShiftTrackingCaregiverActions(
              callbackAction1: callbackAction1,
              callbackAction2: callbackAction2),
        ],
      );
}
