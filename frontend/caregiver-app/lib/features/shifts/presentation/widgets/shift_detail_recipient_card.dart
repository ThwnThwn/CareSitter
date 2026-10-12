import 'package:caregiver_app/features/shifts/presentation/widgets/shift_recipient_identity.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_recipient_emergency_contact.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_recipient_condition.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailRecipientCard extends StatelessWidget {
  const ShiftDetailRecipientCard(
      {super.key, required this.booking, required this.beneficiary});
  final ShiftModel booking;
  final ShiftBeneficiaryModel beneficiary;
  @override
  Widget build(BuildContext context) {
    final displayAge = booking.beneficiaryAge ?? beneficiary.age;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ShiftRecipientIdentity(
              beneficiary: beneficiary,
              displayAge: displayAge,
              booking: booking),
          if (beneficiary.condition.isNotEmpty &&
              beneficiary.condition != 'Chưa có thông tin') ...[
            const SizedBox(height: AppSpacing.compact),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.compact),
            ShiftRecipientCondition(beneficiary: beneficiary),
          ],
          const SizedBox(height: AppSpacing.compact),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.compact),
          ShiftRecipientEmergencyContact(
              beneficiary: beneficiary, callbackAction1: () {}),
        ],
      ),
    );
  }
}
