import 'package:caresitter_customer/core/api/api_cancellation.dart';
import '../../data/models/nutrition_resource_model.dart';
import '../../domain/nutrition_menu_policy.dart';
import '../models/nutrition_failure_model.dart';
import '../models/nutrition_week_generation_result.dart';
import 'nutrition_actions_controller.dart';

/// Runs one batch with a fixed profile revision, pantry and cancellation scope.
class NutritionWeekGenerator {
  NutritionWeekGenerator(this.actions);

  final NutritionActionsController actions;

  Future<
      ({
        NutritionWeekGenerationResult result,
        NutritionResourceModel? firstPlan,
        bool stale,
        bool denied,
      })> generate({
    required String assessmentId,
    required int healthRevision,
    required DateTime startDate,
    required int days,
    required List<String> availableIngredients,
    required ApiCancellation token,
    required bool Function() isCurrent,
    required void Function(int) onProgress,
  }) async {
    final firstDate = NutritionMenuPolicy.dateOnly(startDate);
    var denied = false;
    var created = 0;
    var existing = 0;
    String? failure;
    var stale = false;
    NutritionResourceModel? firstPlan;
    final usedIds = <String>{};
    final usedNames = <String>{};
    try {
      final savedPlans = await actions.plans(token, weekStart: firstDate);
      if (!isCurrent()) {
        return (
          result: NutritionWeekGenerationResult(
              createdDays: created, existingDays: existing, targetDays: days),
          firstPlan: null,
          stale: false,
          denied: false,
        );
      }
      final byDate = <String, NutritionResourceModel>{};
      final lastDate =
          DateTime(firstDate.year, firstDate.month, firstDate.day + days - 1);
      for (final plan in savedPlans) {
        final date = DateTime.tryParse(plan.plannedDate);
        if (plan.id.isEmpty ||
            date == null ||
            date.isBefore(firstDate) ||
            date.isAfter(lastDate) ||
            byDate.containsKey(plan.plannedDate)) {
          continue;
        }
        final stored = await actions.openPlan(plan.id, token);
        if (!isCurrent()) break;
        final signatures = _signatures(stored);
        stale =
            stored.status == 'stale' || stored.healthRevision != healthRevision;
        if (stored.status != 'saved' ||
            stale ||
            !NutritionMenuPolicy.sameDate(
                DateTime.tryParse(stored.result.plannedDate ?? ''), date) ||
            signatures == null ||
            usedIds.contains(signatures.$1) ||
            usedNames.contains(signatures.$2)) {
          failure =
              'Thực đơn ngày ${date.day}/${date.month} cần được kiểm tra lại.';
          break;
        }
        byDate[plan.plannedDate] = stored;
        usedIds.add(signatures.$1);
        usedNames.add(signatures.$2);
      }
      existing = byDate.length;
      onProgress(existing);
      for (var day = 0; day < days && failure == null; day++) {
        if (!isCurrent()) break;
        final date =
            DateTime(firstDate.year, firstDate.month, firstDate.day + day);
        final dateKey = NutritionMenuPolicy.dateKey(date);
        final previous = byDate[dateKey];
        NutritionResourceModel plan;
        if (previous != null) {
          plan = previous;
        } else {
          final suggestion = await actions.recommend(
              assessmentId, healthRevision, token,
              plannedDate: date, availableIngredients: availableIngredients);
          if (!isCurrent()) break;
          stale = suggestion.status == 'stale' ||
              suggestion.healthRevision != healthRevision;
          if (suggestion.status != 'suggested' ||
              stale ||
              !NutritionMenuPolicy.sameDate(
                  DateTime.tryParse(suggestion.result.plannedDate ?? ''),
                  date) ||
              !suggestion.result.decision.allows('save')) {
            failure =
                'Chưa tìm được thực đơn phù hợp cho ngày ${date.day}/${date.month}.';
            break;
          }
          final signatures = _signatures(suggestion);
          if (signatures == null ||
              usedIds.contains(signatures.$1) ||
              usedNames.contains(signatures.$2)) {
            failure =
                'Chưa tìm được thực đơn khác các ngày trước cho ngày ${date.day}/${date.month}.';
            break;
          }
          plan = await actions.save(suggestion.id, healthRevision, token,
              plannedDate: date);
          if (!isCurrent()) break;
          stale =
              plan.status == 'stale' || plan.healthRevision != healthRevision;
          if (plan.status != 'saved' ||
              stale ||
              !NutritionMenuPolicy.sameDate(
                  DateTime.tryParse(plan.result.plannedDate ?? ''), date)) {
            failure = 'Chưa lưu được thực đơn ngày ${date.day}/${date.month}.';
            break;
          }
        }
        final signatures = _signatures(plan);
        if (signatures == null ||
            (previous == null &&
                (usedIds.contains(signatures.$1) ||
                    usedNames.contains(signatures.$2)))) {
          failure =
              'Thực đơn ngày ${date.day}/${date.month} trùng hoặc thiếu bữa.';
          break;
        }
        usedIds.add(signatures.$1);
        usedNames.add(signatures.$2);
        firstPlan ??= plan;
        if (previous == null) created++;
        onProgress(created + existing);
      }
    } catch (error) {
      if (isCurrent()) {
        final failureModel = NutritionFailureModel(error);
        failure = failureModel.message;
        stale = stale || failureModel.stale;
        denied = failureModel.denied;
      }
    }
    return (
      result: NutritionWeekGenerationResult(
          createdDays: created,
          existingDays: existing,
          targetDays: days,
          error: failure),
      firstPlan: firstPlan,
      stale: stale,
      denied: denied,
    );
  }

  (String, String)? _signatures(NutritionResourceModel resource) =>
      NutritionMenuPolicy.signatures(resource.result.meals.map((meal) => (
            mealType: meal.mealType,
            recipeVersionId: meal.recipeVersionId,
            name: meal.name,
          )));
}
