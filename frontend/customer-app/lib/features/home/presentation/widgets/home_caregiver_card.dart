import 'package:caresitter_customer/features/home/presentation/widgets/home_caregiver_card_layout.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeCaregiverCard extends StatelessWidget {
  const HomeCaregiverCard(
      {super.key, required this.c, required this.buildSkillChip});
  final CaregiverModel c;
  final Widget Function(String) buildSkillChip;
  @override
  Widget build(BuildContext context) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();

    return HomeHoverButton(
      onTap: () => context.push(AppRoutes.caregiverDetail(c.id)),
      child: HomeCaregiverCardLayout(
          textScale: textScale, c: c, buildSkillChip: buildSkillChip),
    );
  }
}
