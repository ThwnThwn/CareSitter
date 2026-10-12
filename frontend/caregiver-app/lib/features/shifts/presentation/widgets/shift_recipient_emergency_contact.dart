import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftRecipientEmergencyContact extends StatelessWidget {
  const ShiftRecipientEmergencyContact(
      {super.key, required this.beneficiary, required this.callbackAction1});
  final ShiftBeneficiaryModel beneficiary;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.phone_rounded,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Liên hệ khẩn cấp: ${beneficiary.relation}',
              style: const TextStyle(
                  fontSize: AppFontSizes.s13, color: AppColors.textSecondary),
            ),
          ),
          GestureDetector(
            onTap: callbackAction1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.compact, vertical: AppSpacing.tight),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Text('Gọi',
                  style: TextStyle(
                      fontSize: AppFontSizes.s12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
          ),
        ],
      );
}
