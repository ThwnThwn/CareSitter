import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_caregiver_search.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_trust_badge.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_description.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_actions.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hero_title.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeHeroContent extends StatelessWidget {
  const HomeHeroContent(
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
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(isNarrow ? 14 : AppSpacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge pill
            const HomeHeroTrustBadge(),

            const Spacer(),

            // Headline
            HomeHeroTitle(isNarrow: isNarrow),
            const SizedBox(height: AppSpacing.sm),

            // Description
            HomeHeroDescription(isNarrow: isNarrow),
            SizedBox(height: isNarrow ? 10 : 16),

            // Stats + CTA row
            if (isNarrow)
              HomeHeroActions(stats: stats, callToAction: callToAction)
            else
              Row(
                children: [
                  Expanded(child: stats),
                  const SizedBox(width: AppSpacing.sm),
                  callToAction,
                ],
              ),
            SizedBox(height: isNarrow ? 10 : 16),

            // Search caregivers by name, skill or service location.
            HomeHeroCaregiverSearch(
                isNarrow: isNarrow,
                caregiverSearchController: caregiverSearchController,
                openCaregiverSearch: openCaregiverSearch,
                callbackAction1: callbackAction1),
          ],
        ),
      );
}
