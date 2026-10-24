import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_beneficiary_avatar.dart';

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
          ShiftBeneficiaryAvatar(
            name: beneficiary.name,
            age: displayAge > 0 ? displayAge : booking.beneficiaryAge,
            gender: booking.beneficiaryGender,
            avatarUrl: booking.beneficiaryAvatarUrl,
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
