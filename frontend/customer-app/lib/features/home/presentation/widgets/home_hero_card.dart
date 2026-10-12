import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_content.dart';
import 'package:flutter/material.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard(
      {super.key,
      required this.isNarrow,
      required this.stats,
      required this.callToAction,
      required this.caregiverSearchController,
      required this.openCaregiverSearch,
      required this.callbackAction1});
  final bool isNarrow;
  final Widget stats;
  final Widget callToAction;
  final TextEditingController caregiverSearchController;
  final void Function([String?]) openCaregiverSearch;
  final void Function(PointerDownEvent) callbackAction1;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: HomeHeroContent(
            isNarrow: isNarrow,
            stats: stats,
            callToAction: callToAction,
            caregiverSearchController: caregiverSearchController,
            openCaregiverSearch: openCaregiverSearch,
            callbackAction1: callbackAction1),
      );
}
