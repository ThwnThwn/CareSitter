import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftChecklistNotes extends StatelessWidget {
  const ShiftChecklistNotes({super.key, required this.beneficiary});
  final ShiftBeneficiaryModel beneficiary;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_outlined,
              size: 15, color: AppColors.textHint),
          const SizedBox(width: AppSpacing.tight),
          Expanded(
            child: Text(beneficiary.notes,
                style: const TextStyle(
                    fontSize: AppFontSizes.s13,
                    color: AppColors.textSecondary,
                    height: 1.4)),
          ),
        ],
      );
}
