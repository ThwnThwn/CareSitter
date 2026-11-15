import 'package:caregiver_app/core/router/app_routes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/shift_model.dart';

class ShiftMealLink extends StatelessWidget {
  const ShiftMealLink({super.key, required this.shift});
  final ShiftModel shift;

  @override
  Widget build(BuildContext context) {
    if (!const {
      ShiftStatus.confirmed,
      ShiftStatus.caregiverEnRoute,
      ShiftStatus.inProgress,
      ShiftStatus.checkoutPendingReview,
    }.contains(shift.statusType)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.compact),
      child: OutlinedButton.icon(
        onPressed: () => context.push(AppRoutes.shiftMeals(shift.id)),
        icon: const Icon(Icons.restaurant_menu_rounded),
        label: const Text('Bữa ăn trong ca'),
      ),
    );
  }
}
