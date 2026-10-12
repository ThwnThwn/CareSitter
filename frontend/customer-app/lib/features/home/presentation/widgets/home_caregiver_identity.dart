import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeCaregiverIdentity extends StatelessWidget {
  const HomeCaregiverIdentity({super.key, required this.c});
  final CaregiverModel c;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              c.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          if (c.isOnline)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      );
}
