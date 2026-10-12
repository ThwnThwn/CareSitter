import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_header_caregiver_panel.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileHeaderCaregiverContent extends StatelessWidget {
  const CaregiverProfileHeaderCaregiverContent(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;

  @override
  Widget build(BuildContext context) => FlexibleSpaceBar(
        background: CaregiverProfileHeaderCaregiverPanel(caregiver: caregiver),
      );
}
