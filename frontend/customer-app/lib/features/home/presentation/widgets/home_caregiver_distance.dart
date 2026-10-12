import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeCaregiverDistance extends StatelessWidget {
  const HomeCaregiverDistance({super.key, required this.c});
  final CaregiverModel c;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.near_me_outlined,
                  size: 13, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                  child: Text('Khoảng ${c.distanceLabel}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: AppFontSizes.s12))),
            ]),
            const SizedBox(height: AppSpacing.sm),
          ]);
}
