import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileHeaderCaregiverDecoration extends StatelessWidget {
  const CaregiverProfileHeaderCaregiverDecoration(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Hero(
            tag: 'caregiver-avatar-${caregiver.id}',
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              child: Text(
                caregiver.initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSizes.s20,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (caregiver.isOnline)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
        ],
      );
}
