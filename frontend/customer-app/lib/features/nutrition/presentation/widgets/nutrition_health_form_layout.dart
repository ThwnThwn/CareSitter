import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'nutrition_required_header.dart';

class NutritionHealthFormLayout extends StatelessWidget {
  const NutritionHealthFormLayout({
    super.key,
    required this.reportedFields,
    required this.preferencesPanel,
    required this.healthFields,
    required this.notesFields,
    this.saveButton,
  });

  final Widget reportedFields;
  final Widget preferencesPanel;
  final Widget healthFields;
  final Widget notesFields;
  final Widget? saveButton;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NutritionRequiredHeader(),
          const SizedBox(height: AppSpacing.md),
          reportedFields,
          preferencesPanel,
          const SizedBox(height: AppSpacing.compact),
          healthFields,
          const SizedBox(height: AppSpacing.compact),
          notesFields,
          const SizedBox(height: AppSpacing.md),
          if (saveButton != null) saveButton!,
        ],
      );
}
