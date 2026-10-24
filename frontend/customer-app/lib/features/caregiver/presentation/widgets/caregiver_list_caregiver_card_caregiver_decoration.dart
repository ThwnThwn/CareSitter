import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverListCaregiverCardCaregiverDecoration extends StatelessWidget {
  const CaregiverListCaregiverCardCaregiverDecoration(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;
  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Hero(
            tag: 'caregiver-avatar-${caregiver.id}',
            child: CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primaryContainer,
              backgroundImage:
                  AssetImage(defaultAvatarAsset(seed: caregiver.initials)),
            ),
          ),
          if (caregiver.isOnline)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      );
}
