import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_source_model.dart';
import 'package:flutter/material.dart';

class NutritionMealSources extends StatelessWidget {
  const NutritionMealSources({
    super.key,
    required this.sourceIds,
    required this.sources,
  });

  final List<String> sourceIds;
  final List<NutritionSourceModel> sources;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      if (sourceIds.isEmpty) return const SizedBox.shrink();
      return Text('Mã nguồn: ${sourceIds.join('; ')}');
    }

    return Semantics(
      container: true,
      label: 'Nguồn đã đối chiếu cho món ăn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nguồn đã đối chiếu',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final source in sources) ...[
            _SourceRow(source: source),
            if (source != sources.last)
              const SizedBox(height: AppSpacing.compact),
          ],
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final NutritionSourceModel source;

  @override
  Widget build(BuildContext context) {
    final attribution = [
      source.organization,
      if (source.year case final year?) year.toString(),
    ].where((value) => value.isNotEmpty).join(' · ');
    final location = [
      if (source.edition.isNotEmpty) 'Ấn bản ${source.edition}',
      if (source.chapter.isNotEmpty) source.chapter,
      if (source.printedPages.isNotEmpty) 'Trang in ${source.printedPages}',
      if (source.pdfPages.isNotEmpty) 'Trang PDF ${source.pdfPages}',
    ].join(' · ');
    final verifiedOn = source.verifiedOn;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.micro),
          child: Icon(
            Icons.menu_book_outlined,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                source.title.isEmpty ? source.id : source.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (attribution.isNotEmpty)
                Text(attribution, style: Theme.of(context).textTheme.bodySmall),
              if (location.isNotEmpty)
                Text(location, style: Theme.of(context).textTheme.bodySmall),
              if (source.locator.isNotEmpty)
                Text(source.locator,
                    style: Theme.of(context).textTheme.bodySmall),
              if (source.reference.isNotEmpty)
                Text(
                  source.reference,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.visible,
                ),
              if (verifiedOn != null)
                Text(
                  'Đối chiếu ngày ${formatDate(verifiedOn, padded: true)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
