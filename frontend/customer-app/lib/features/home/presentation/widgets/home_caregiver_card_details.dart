import 'package:caresitter_customer/features/home/presentation/widgets/home_caregiver_identity.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_caregiver_rating.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_caregiver_details_link.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_caregiver_price.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_caregiver_distance.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_caregiver_skills.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeCaregiverCardDetails extends StatelessWidget {
  const HomeCaregiverCardDetails(
      {super.key, required this.c, required this.buildSkillChip});
  final CaregiverModel c;
  final Widget Function(String) buildSkillChip;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeCaregiverIdentity(c: c),
          const SizedBox(height: AppSpacing.control),
          HomeCaregiverPrice(c: c),
          const SizedBox(height: AppSpacing.xs),
          HomeCaregiverRating(c: c),
          const SizedBox(height: AppSpacing.sm),
          if (c.distanceLabel != null) HomeCaregiverDistance(c: c),
          if (c.skills.isNotEmpty)
            HomeCaregiverSkills(buildSkillChip: buildSkillChip, c: c),
          const Spacer(),
          const HomeCaregiverDetailsLink(),
        ],
      );
}
