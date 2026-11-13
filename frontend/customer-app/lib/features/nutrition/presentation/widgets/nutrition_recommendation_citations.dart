import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_recommendation_trace_model.dart';
import 'package:flutter/material.dart';

class NutritionRecommendationCitations extends StatelessWidget {
  const NutritionRecommendationCitations({super.key, required this.trace});

  final NutritionRecommendationTraceModel trace;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('Tài liệu tham khảo',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Nguồn được truy xuất để tham khảo; chưa xác minh liên hệ với từng món:',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            for (final citation in trace.citations)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(citation.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (citation.chapter?.isNotEmpty == true)
                        Text('Chương: ${citation.chapter}',
                            style: Theme.of(context).textTheme.bodySmall),
                      if (citation.heading?.isNotEmpty == true)
                        Text('Mục: ${citation.heading}',
                            style: Theme.of(context).textTheme.bodySmall),
                      if (citation.pages?.isNotEmpty == true)
                        Text('Trang: ${citation.pages}',
                            style: Theme.of(context).textTheme.bodySmall),
                      if ((trace.hasGraphExplanation ||
                              trace.usesGraphRetrieval) &&
                          citation.graphPath.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text('Đường dẫn graph:',
                            style: Theme.of(context).textTheme.bodySmall),
                        for (final step in citation.graphPath)
                          Text(
                            '• ${step.heading?.isNotEmpty == true ? step.heading : step.nodeId}'
                            '${step.pages.isEmpty ? '' : ' · trang ${step.pages.join(', ')}'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
