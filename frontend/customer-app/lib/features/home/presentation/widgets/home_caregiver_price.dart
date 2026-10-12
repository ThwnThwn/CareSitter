import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeCaregiverPrice extends StatelessWidget {
  const HomeCaregiverPrice({super.key, required this.c});
  final CaregiverModel c;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              c.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.verified_rounded,
              color: AppColors.primary, size: 14),
        ],
      );
}
