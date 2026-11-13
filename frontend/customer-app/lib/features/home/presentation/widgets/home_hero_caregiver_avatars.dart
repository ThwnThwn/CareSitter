import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeHeroCaregiverAvatars extends StatelessWidget {
  const HomeHeroCaregiverAvatars({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/home-care-banner.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.primaryContainer,
          child: const Icon(Icons.elderly_woman_rounded,
              size: 80, color: AppColors.primary),
        ),
      );
}
