import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftRecipientCondition extends StatelessWidget {
  const ShiftRecipientCondition({super.key, required this.beneficiary});
  final ShiftBeneficiaryModel beneficiary;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.textHint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              beneficiary.condition,
              style: const TextStyle(
                  fontSize: AppFontSizes.s13,
                  color: AppColors.textSecondary,
                  height: 1.4),
            ),
          ),
        ],
      );
}
