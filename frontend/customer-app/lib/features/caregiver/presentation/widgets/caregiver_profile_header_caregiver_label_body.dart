import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileHeaderCaregiverLabelBody extends StatelessWidget {
  const CaregiverProfileHeaderCaregiverLabelBody(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;

  @override
  Widget build(BuildContext context) => Text(
        caregiver.displayName,
        maxLines: 2,
        overflow: TextOverflow.fade,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white,
            fontSize: AppFontSizes.s20,
            fontWeight: FontWeight.w700),
      );
}
