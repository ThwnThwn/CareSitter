import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeHeroActions extends StatelessWidget {
  const HomeHeroActions(
      {super.key, required this.stats, required this.callToAction});
  final Widget stats;
  final Widget callToAction;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stats,
          const SizedBox(height: AppSpacing.tight),
          Align(
            alignment: Alignment.centerRight,
            child: callToAction,
          ),
        ],
      );
}
