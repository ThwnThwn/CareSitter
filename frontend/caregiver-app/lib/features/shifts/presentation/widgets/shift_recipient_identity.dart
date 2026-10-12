import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftRecipientIdentity extends StatelessWidget {
  const ShiftRecipientIdentity(
      {super.key,
      required this.beneficiary,
      required this.displayAge,
      required this.booking});
  final ShiftBeneficiaryModel beneficiary;
  final int displayAge;
  final ShiftModel booking;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              beneficiary.avatarInitial,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s18,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(beneficiary.name,
                    style: const TextStyle(
                        fontSize: AppFontSizes.s16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  displayAge > 0
                      ? '$displayAge tuổi • ${booking.serviceName}'
                      : booking.serviceName,
                  style: const TextStyle(
                      fontSize: AppFontSizes.s13,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );
}
