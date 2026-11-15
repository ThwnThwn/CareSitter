import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/nutrition_knowledge_model.dart';

class NutritionKnowledgeSourceCard extends StatefulWidget {
  const NutritionKnowledgeSourceCard(
      {super.key, required this.hit, required this.showExcerpt, this.citation});
  final NutritionKnowledgeHitModel hit;
  final bool showExcerpt;
  final int? citation;

  @override
  State<NutritionKnowledgeSourceCard> createState() =>
      _NutritionKnowledgeSourceCardState();
}

class _NutritionKnowledgeSourceCardState
    extends State<NutritionKnowledgeSourceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hit = widget.hit;
    final excerpt = hit.excerpt?.trim() ?? '';
    final summary = hit.summary?.trim() ?? '';
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${widget.citation == null ? '' : '[${widget.citation}] '}${hit.heading}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
            if (widget.showExcerpt && summary.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text('Tóm tắt mục',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(summary),
              const SizedBox(height: AppSpacing.xs),
              Text('Lược chọn câu từ mục tài liệu trên trang này.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
            if (widget.showExcerpt && summary.isEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                  'Mục này chưa có đủ văn bản rõ để tóm tắt. Hãy đối chiếu trang nguồn.'),
            ],
            if (widget.showExcerpt &&
                excerpt.isNotEmpty &&
                !summary.contains(excerpt)) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text('Đoạn khớp câu hỏi',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              if (_expanded)
                SelectableText(excerpt)
              else
                Text(excerpt, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (excerpt.length > 180)
                TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded
                        ? 'Thu gọn đoạn trích'
                        : 'Xem đầy đủ đoạn trích')),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
                '${hit.sourceTitle} · Trang PDF ${hit.pdfPage}${hit.printedPage == null ? '' : ' · Trang in ${hit.printedPage}'}',
                style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      ),
    ));
  }
}
