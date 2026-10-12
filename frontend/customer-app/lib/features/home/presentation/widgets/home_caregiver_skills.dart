import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeCaregiverSkills extends StatelessWidget {
  const HomeCaregiverSkills(
      {super.key, required this.buildSkillChip, required this.c});
  final Widget Function(String) buildSkillChip;
  final CaregiverModel c;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(
                  child: buildSkillChip(c.skills.first),
                ),
                if (c.skills.length > 1) ...[
                  const SizedBox(width: AppSpacing.xs),
                  buildSkillChip('+${c.skills.length - 1}'),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ]);
}
