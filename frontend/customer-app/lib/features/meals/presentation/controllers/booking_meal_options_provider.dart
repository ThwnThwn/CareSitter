import 'package:caresitter_customer/core/auth/auth_session_scope.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_plan_summary_model.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/booking_meals_model.dart';

final bookingMealOptionsProvider = FutureProvider.autoDispose
    .family<List<MealPlanSummaryModel>, BookingMealShareWindow>(
        (ref, window) async {
  final session = AuthSessionScope.watch(ref);
  final nutrition = ref.read(nutritionRepositoryProvider);
  final plans = <MealPlanSummaryModel>[];
  // The endpoint accepts seven calendar dates starting at the given date.
  for (var start = window.firstDate;
      !start.isAfter(window.lastDate);
      start = start.add(const Duration(days: 7))) {
    session.requireCurrent();
    plans.addAll(await nutrition.savedPlans(
        window.beneficiaryId, session.cancellation,
        weekStart: start));
  }
  session.requireCurrent();
  final firstDate = window.firstDate.toIso8601String().split('T').first;
  final lastDate = window.lastDate.toIso8601String().split('T').first;
  return plans
      .where((plan) =>
          plan.id.isNotEmpty &&
          plan.plannedDate.compareTo(firstDate) >= 0 &&
          plan.plannedDate.compareTo(lastDate) <= 0)
      .toList(growable: false);
});
