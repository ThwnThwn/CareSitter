import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/router/app_routes.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/booking_meal_model.dart';
import '../../data/models/booking_meal_plan_model.dart';
import '../../data/models/booking_meal_record_model.dart';
import '../controllers/booking_meals_controller.dart';
import '../models/booking_meal_copy.dart';
import '../widgets/booking_meal_day.dart';
import '../widgets/booking_meal_editor.dart';

class BookingMealsScreen extends ConsumerWidget {
  const BookingMealsScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = bookingMealsProvider(bookingId);
    final state = ref.watch(provider);
    final data = state.isReloading ? null : state.valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bữa ăn trong ca'),
        leading: AppBackButton(fallbackRoute: AppRoutes.shiftDetail(bookingId)),
        actions: [
          IconButton(
            tooltip: 'Tải lại bữa ăn',
            onPressed: state.isLoading ? null : () => ref.invalidate(provider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (state.isLoading)
                const LinearProgressIndicator(
                    semanticsLabel: 'Đang tải bữa ăn'),
              if (state.hasError && !state.isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(mealApiError(state.error)),
                ),
              if (data?.plans.isEmpty == true)
                const Text('Gia đình chưa chia sẻ thực đơn cho ca này.'),
              for (final plan in data?.plans ?? <BookingMealPlanModel>[])
                BookingMealDay(
                  key: ValueKey(plan.plannedDate),
                  plan: plan,
                  records: data!.records
                      .where((r) => r.planId == plan.planId)
                      .toList(),
                  onRecord: (meal) => _edit(context, ref, plan, meal: meal),
                  onCorrect: (record) =>
                      _edit(context, ref, plan, record: record),
                  disabled: state.isLoading,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, BookingMealPlanModel plan,
      {BookingMealModel? meal, BookingMealRecordModel? record}) async {
    final session = _session(ref);
    final provider = bookingMealsProvider(bookingId);
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (_) => BookingMealEditor(
        record: record,
        mealLabel:
            '${meal?.name ?? mealTypeLabel(record!.mealType)} · ${mealDateLabel(plan.plannedDate)}',
        onSave: (outcome, note, reason) async {
          if (!context.mounted || session != _session(ref)) {
            return 'Phiên đăng nhập đã thay đổi.';
          }
          final controller = ref.read(provider.notifier);
          final saved = record == null
              ? await controller.record(
                  planId: plan.planId,
                  recipeVersionId: meal!.versionId,
                  mealType: meal.mealType,
                  outcome: outcome,
                  note: note)
              : await controller.correct(
                  recordId: record.id,
                  outcome: outcome,
                  reason: reason!,
                  expectedRevision: record.revision,
                  note: note);
          if (!context.mounted || session != _session(ref)) {
            return 'Phiên đăng nhập đã thay đổi.';
          }
          return saved ? null : mealApiError(ref.read(provider).error);
        },
      ),
    );
    if (context.mounted && done == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            record == null ? 'Đã lưu ghi nhận bữa ăn.' : 'Đã lưu đính chính.'),
      ));
    }
  }

  (String?, int) _session(WidgetRef ref) => (
        ref.read(authStateProvider).valueOrNull?.userId,
        ref.read(authStateProvider.notifier).sessionGeneration,
      );
}
