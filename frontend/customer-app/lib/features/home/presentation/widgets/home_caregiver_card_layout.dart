import 'package:caresitter_customer/features/home/presentation/widgets/home_caregiver_card_details.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeCaregiverCardLayout extends StatelessWidget {
  const HomeCaregiverCardLayout(
      {super.key,
      required this.textScale,
      required this.c,
      required this.buildSkillChip});
  final double textScale;
  final CaregiverModel c;
  final Widget Function(String) buildSkillChip;

  @override
  Widget build(BuildContext context) => Container(
        width: 180 * textScale,
        constraints:
            BoxConstraints(minHeight: c.distanceLabel == null ? 220 : 246),
        padding: const EdgeInsets.all(AppSpacing.inset),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: HomeCaregiverCardDetails(c: c, buildSkillChip: buildSkillChip),
      );
}
