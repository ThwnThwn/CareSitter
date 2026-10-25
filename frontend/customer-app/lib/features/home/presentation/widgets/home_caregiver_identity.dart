import 'package:caresitter_customer/core/utils/default_avatar.dart';
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
            backgroundImage: AssetImage(defaultAvatarAsset(seed: c.initials)),
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
