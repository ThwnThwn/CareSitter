import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_recommendation_trace_model.dart';
import 'package:flutter/material.dart';

class NutritionRecommendationContext extends StatelessWidget {
  const NutritionRecommendationContext({
    super.key,
    required this.trace,
    required this.meals,
  });

  final NutritionRecommendationTraceModel trace;
  final List<NutritionMealModel> meals;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.compact),
      elevation: 0,
      color: AppColors.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.compact),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trace.isDemo) ...[
              _DemoNotice(graphUsed: trace.isGraphDemo && trace.isGrounded),
              const SizedBox(height: AppSpacing.compact),
            ],
            _RecommendationSummary(trace: trace),
            if (trace.usedAi &&
                trace.isGrounded &&
                trace.explanations.isNotEmpty)
              _RecommendationExplanations(trace: trace, meals: meals),
            if (trace.evidence.isNotEmpty) _RecommendationSources(trace: trace),
          ],
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.graphUsed});
  final bool graphUsed;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              graphUsed ? 'DEMO · GraphRAG' : 'DEMO',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chưa kiểm duyệt lâm sàng. Nội dung chỉ dùng tham khảo trong bản demo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      );
}

class _RecommendationSummary extends StatelessWidget {
  const _RecommendationSummary({required this.trace});
  final NutritionRecommendationTraceModel trace;

  @override
  Widget build(BuildContext context) {
    final aiGrounded = trace.usedAi && trace.isGrounded;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          aiGrounded ? Icons.auto_awesome_rounded : Icons.rule_outlined,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                aiGrounded
                    ? 'AI gợi ý dựa trên tài liệu tham khảo'
                    : 'Gợi ý theo bộ quy tắc an toàn',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                aiGrounded
                    ? 'AI chỉ xếp hạng các món đã qua kiểm tra dị ứng và giới hạn dinh dưỡng.'
                    : trace.isGrounded
                        ? 'Thực đơn được đối chiếu tài liệu sau khi kiểm tra dị ứng và giới hạn dinh dưỡng; AI không tham gia chọn món.'
                        : 'Thực đơn được chọn từ catalog sau khi kiểm tra dị ứng và giới hạn dinh dưỡng.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationExplanations extends StatelessWidget {
  const _RecommendationExplanations({required this.trace, required this.meals});
  final NutritionRecommendationTraceModel trace;
  final List<NutritionMealModel> meals;

  @override
  Widget build(BuildContext context) {
    final mealNames = {
      for (final meal in meals) meal.recipeVersionId: meal.name
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final explanation in trace.explanations)
            if (mealNames[explanation.recipeVersionId] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '• ${mealNames[explanation.recipeVersionId]}: ${explanation.summary}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
        ],
      ),
    );
  }
}

class _RecommendationSources extends StatelessWidget {
  const _RecommendationSources({required this.trace});
  final NutritionRecommendationTraceModel trace;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            '${trace.evidence.length} nguồn dùng để đối chiếu',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          children: [
            for (final evidence in trace.evidence)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '• ${evidence.reference}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ),
          ],
        ),
      );
}
