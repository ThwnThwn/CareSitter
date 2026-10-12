import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_header_caregiver_decoration.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_header_caregiver_row.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_header_caregiver_label.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_header_caregiver_label_body.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_header_caregiver_fields.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileHeaderCaregiverPanel extends StatelessWidget {
  const CaregiverProfileHeaderCaregiverPanel(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              CaregiverProfileHeaderCaregiverDecoration(caregiver: caregiver),
              const SizedBox(height: AppSpacing.control),
              CaregiverProfileHeaderCaregiverLabelBody(caregiver: caregiver),
              const SizedBox(height: AppSpacing.xs),
              CaregiverProfileHeaderCaregiverLabel(caregiver: caregiver),
              const SizedBox(height: AppSpacing.sm),
              CaregiverProfileHeaderCaregiverRow(caregiver: caregiver),
              if (caregiver.location.isNotEmpty)
                CaregiverProfileHeaderCaregiverFields(caregiver: caregiver),
            ],
          ),
        ),
      );
}
