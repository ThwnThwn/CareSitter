import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Presentation metadata shared by meal headers and meal cards.
class NutritionMealPresentation {
  const NutritionMealPresentation({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.imageAsset,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String imageAsset;

  factory NutritionMealPresentation.forType(String type) => switch (type) {
        'lunch' => const NutritionMealPresentation(
            label: 'Bữa trưa',
            icon: Icons.wb_sunny_outlined,
            iconColor: Color(0xFFE67E22),
            backgroundColor: Color(0xFFFFF3E0),
            imageAsset: 'assets/images/nutrition-lunch-illustration.jpg',
          ),
        'dinner' => const NutritionMealPresentation(
            label: 'Bữa tối',
            icon: Icons.nightlight_round,
            iconColor: Color(0xFF5C6BC0),
            backgroundColor: Color(0xFFEDE7F6),
            imageAsset: 'assets/images/nutrition-dinner-illustration.jpg',
          ),
        _ => const NutritionMealPresentation(
            label: 'Bữa sáng',
            icon: Icons.wb_twilight_outlined,
            iconColor: AppColors.primary,
            backgroundColor: AppColors.primaryContainer,
            imageAsset: 'assets/images/nutrition-breakfast-illustration.jpg',
          ),
      };
}
