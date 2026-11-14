import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/nutrition_knowledge_model.dart';
import '../models/nutrition_knowledge_presentation.dart';
import 'nutrition_knowledge_source_card.dart';

class NutritionKnowledgeResults extends StatelessWidget {
  const NutritionKnowledgeResults({super.key, required this.search});
  final NutritionKnowledgeSearchModel search;

  @override
  Widget build(BuildContext context) {
    final presentation = NutritionKnowledgePresentation(search);
    final hasAnswer = presentation.hasAnswer;
    final sources = hasAnswer ? search.answerSources : search.results;
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (search.localDemo || search.generalKnowledge) ...[
        Text(
            search.isAiSuggestion || search.generalKnowledge
                ? 'AI đề xuất · Gemini'
                : 'Câu trả lời từ tài liệu${search.answerProvider == 'Gemini' ? ' · Gemini' : ' · Demo local'}',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SelectableText(presentation.answerText))),
        if (search.isAiSuggestion)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
                'Gợi ý từ kiến thức chung của AI, chưa được đối chiếu với tài liệu. Nội dung chỉ mang tính tham khảo.'),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (sources.isNotEmpty) ...[
        Text(
            hasAnswer
                ? 'Nguồn đã dùng'
                : search.localDemo
                    ? 'Đoạn liên quan để đối chiếu'
                    : 'Kết quả cho “${search.query}”',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final (index, hit) in sources.indexed) ...[
          NutritionKnowledgeSourceCard(
            key: ValueKey('${search.query}:${hit.chunkId}'),
            hit: hit,
            citation: hasAnswer &&
                    (search.answerProvider == 'Gemini' || sources.length > 1)
                ? index + 1
                : null,
            showExcerpt: search.localDemo,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    ]);
  }
}
