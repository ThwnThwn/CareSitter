import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/nutrition_recommendation_explanation_model.dart';
import '../../data/models/nutrition_recommendation_trace_model.dart';

class NutritionMealAiReason extends StatelessWidget {
  const NutritionMealAiReason(
      {super.key, required this.explanation, required this.trace});

  final NutritionRecommendationExplanationModel explanation;
  final NutritionRecommendationTraceModel trace;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.compact),
            decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.compact)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Giải thích từ AI',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text(explanation.summary.trim(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.6)),
            ]),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Nguồn AI tham khảo:',
              style: Theme.of(context).textTheme.labelSmall),
          for (final evidence in trace.evidence
              .where((item) => explanation.evidenceIds.contains(item.id)))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                  [
                    evidence.title,
                    evidence.reference,
                    if (evidence.chapter case final chapter?) chapter,
                    if (evidence.printedPages case final pages?)
                      'Trang in $pages',
                  ].where((text) => text.isNotEmpty).join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary, height: 1.5)),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
              'Diễn giải của AI mang tính tham khảo, chưa được kiểm duyệt lâm sàng.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
        ],
      );
}
