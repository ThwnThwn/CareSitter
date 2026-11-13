import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_recommendation_trace_model.dart';
import 'package:flutter/material.dart';

import '../../domain/nutrition_disclaimer.dart';
import 'nutrition_recommendation_citations.dart';
import 'nutrition_reference_text.dart';
import '../models/nutrition_reason_copy.dart';

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
            if (trace.isDemo ||
                meals.any((meal) => meal.name.startsWith('[DEMO]'))) ...[
              _DemoNotice(graphUsed: trace.isGraphDemo && trace.isGrounded),
              const SizedBox(height: AppSpacing.compact),
            ],
            if (trace.isReference) ...[
              Text(_releaseLabel(trace),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.warning, fontWeight: FontWeight.w700)),
              Text(trace.disclaimer ?? NutritionDisclaimer.reference,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (trace.isReviewedRelease) ...[
              Text(_releaseLabel(trace),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
              Text(trace.disclaimer ?? NutritionDisclaimer.reviewed,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (trace.releaseStatus == 'ungrounded') ...[
              Text('Gợi ý theo quy tắc, chưa có trích dẫn',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
            ],
            _RecommendationSummary(trace: trace),
            _MenuCriteria(trace: trace),
            if (trace.isGrounded) _RecommendationSources(trace: trace),
            if (trace.isGrounded && trace.citations.isNotEmpty)
              NutritionRecommendationCitations(trace: trace),
          ],
        ),
      ),
    );
  }
}

// "GraphRAG" is claimed only when the validated release retrieved through the
// graph; an explanation-only graph never ranks or retrieves.
String _releaseLabel(NutritionRecommendationTraceModel trace) =>
    trace.usesGraphRetrieval
        ? 'Tham khảo · GraphRAG'
        : trace.hasGraphExplanation
            ? 'Tham khảo · Trích dẫn sách + đồ thị nguồn'
            : 'Tham khảo · Trích dẫn sách';

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
                aiGrounded ? 'AI CareSitter đề xuất' : 'CareSitter đề xuất',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (trace.isReference || trace.isReviewedRelease) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  trace.usesGraphRetrieval
                      ? 'Graph đã tham gia tra cứu nguồn.'
                      : trace.hasGraphExplanation
                          ? 'Graph chỉ giải thích đường dẫn nguồn; không xếp hạng món.'
                          : 'Graph không tham gia tra cứu hoặc giải thích.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                aiGrounded
                    ? 'AI xếp hạng các phương án đã qua bộ lọc dị ứng và các quy tắc dinh dưỡng hiện có.'
                    : trace.isGrounded
                        ? 'Thực đơn được chọn theo quy tắc và có tài liệu tham khảo; AI không tham gia chọn món.'
                        : 'Thực đơn được chọn theo các quy tắc hiện có; AI không tham gia chọn món.',
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

class _MenuCriteria extends StatelessWidget {
  const _MenuCriteria({required this.trace});
  final NutritionRecommendationTraceModel trace;

  @override
  Widget build(BuildContext context) {
    final visibleReasons = trace.verifiedReasons
        .where((reason) =>
            reason['recipeVersionId'] == NutritionReasonCopy.menuId &&
            NutritionReasonCopy.detail(reason, null) != null)
        .toList();
    if (visibleReasons.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text('Tiêu chí chung của thực đơn',
            style: Theme.of(context).textTheme.titleSmall),
        children: [
          for (final reason in visibleReasons)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '• ${NutritionReasonCopy.detail(reason, null)}\n'
                'Mục hồ sơ: ${NutritionReasonCopy.source(reason['sourceField'])}'
                '${reason['code'] == 'condition_rule' ? '\nNguồn quy tắc: ${(reason['sourceIds'] is List ? reason['sourceIds'] as List : const []).join(', ')}. Chưa có đoạn trích đã xác minh để hiển thị.' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
              'Các kiểm tra này chưa chứng minh thực đơn phù hợp để điều trị bệnh.'),
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
                  child: NutritionReferenceText(evidence.reference),
                ),
              ),
          ],
        ),
      );
}
