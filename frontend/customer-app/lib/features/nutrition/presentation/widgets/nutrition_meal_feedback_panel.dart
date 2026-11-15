import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import '../controllers/meal_feedback_controller.dart';
import '../models/meal_feedback_copy.dart';

class NutritionMealFeedbackPanel extends ConsumerWidget {
  const NutritionMealFeedbackPanel({super.key, required this.scope});
  final MealFeedbackScope scope;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealFeedbackProvider(scope));
    final data = state.valueOrNull;
    final controller = ref.read(mealFeedbackProvider(scope).notifier);
    final date = DateTime.tryParse(data?.plan.result.plannedDate ?? '');
    final today = DateTime.now().toUtc().add(const Duration(hours: 7));
    final canRecord = date != null &&
        !date.isAfter(DateTime(today.year, today.month, today.day));
    return ListView(
        padding: const EdgeInsets.all(AppSpacing.section),
        children: [
          Text('Món người thân ăn hợp',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text(
              'Phản hồi chỉ trở thành sở thích sau khi gia đình duyệt. Thực đơn đã lưu được giữ nguyên; lần gợi ý sau cần kiểm tra hồ sơ cập nhật.'),
          if (state.isLoading) const LinearProgressIndicator(),
          if (state.hasError) ...[
            Text(state.error is AppApiException
                ? (state.error as AppApiException).message
                : 'Chưa tải được phản hồi. Vui lòng thử lại.'),
            TextButton(
                onPressed: () => ref.invalidate(mealFeedbackProvider(scope)),
                child: const Text('Tải lại phản hồi')),
          ],
          if (data != null) ...[
            if (!canRecord)
              const Text('Bạn có thể phản hồi từ ngày dùng thực đơn.'),
            for (final meal in data.plan.result.meals) ...[
              const Divider(height: AppSpacing.lg),
              Text(meal.name, style: Theme.of(context).textTheme.titleSmall),
              if (canRecord &&
                  !data.feedback.items.any((item) =>
                      item.recipeVersionId == meal.recipeVersionId &&
                      item.submittedByRole == 'CUSTOMER' &&
                      item.status != 'rejected'))
                Wrap(spacing: AppSpacing.sm, children: [
                  for (final choice in MealFeedbackCopy.labels.entries)
                    OutlinedButton(
                        onPressed: state.isLoading
                            ? null
                            : () => controller.submit(
                                meal.recipeVersionId, choice.key),
                        child: Text(choice.value)),
                ]),
              for (final item in data.feedback.items.where(
                  (item) => item.recipeVersionId == meal.recipeVersionId)) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                    'Gia đình: ${MealFeedbackCopy.labels[item.feedback] ?? item.feedback}'),
                if (item.status == 'pending') ...[
                  Text(MealFeedbackCopy.effect(item.mealName, item.feedback)),
                  Wrap(spacing: AppSpacing.sm, children: [
                    FilledButton(
                        onPressed: state.isLoading
                            ? null
                            : () => controller.review(item.id, true),
                        child: const Text('Duyệt cập nhật sở thích')),
                    TextButton(
                        onPressed: state.isLoading
                            ? null
                            : () => controller.review(item.id, false),
                        child: const Text('Bỏ qua')),
                  ]),
                ] else
                  Text(item.status == 'approved'
                      ? 'Đã cập nhật sở thích'
                      : 'Đã bỏ qua'),
              ],
            ],
          ],
        ]);
  }
}
