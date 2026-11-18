import 'dart:async';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_actions_controller.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_week_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/nutrition_flow_repository.dart';

void main() {
  test('cancelled batch ignores a late history result and never starts a write',
      () async {
    final repository = NutritionFlowRepository()
      ..pendingWeekList = Completer<void>();
    final generator = NutritionWeekGenerator(
        NutritionActionsController(repository, 'person'));
    var active = true;
    final progress = <int>[];
    final pending = generator.generate(
      assessmentId: 'assessment',
      healthRevision: 7,
      startDate: DateTime(2026, 11, 17),
      days: 3,
      availableIngredients: const [],
      token: ApiCancellation(),
      isCurrent: () => active,
      onProgress: progress.add,
    );
    active = false;
    repository.pendingWeekList!.complete();
    final outcome = await pending;
    expect(repository.writes, isEmpty);
    expect(progress, isEmpty);
    expect(outcome.firstPlan, isNull);
    expect(outcome.result.createdDays, 0);
  });
}
