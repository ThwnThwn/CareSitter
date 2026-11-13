import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_source_model.dart';
import 'package:flutter/material.dart';

import 'nutrition_reference_text.dart';
import '../models/nutrition_source_copy.dart';

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
      if (sourceIds.isEmpty) return const Text('Chưa có thông tin nguồn');
      return Text('Mã nguồn: ${sourceIds.join('; ')}');
    }

    return Semantics(
      container: true,
      label: 'Nguồn tham khảo của món ăn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nguồn tham khảo',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final source in sources) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.compact),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.compact)),
              child: _SourceRow(source: source),
            ),
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
      if (source.chapter.isNotEmpty && !NutritionSourceCopy.isAdapted(source))
        source.chapter,
      if (source.printedPages.isNotEmpty) 'Trang in ${source.printedPages}',
      if (source.pdfPages.isNotEmpty) 'Trang PDF ${source.pdfPages}',
    ].join(' · ');
    final verifiedOn = source.verifiedOn;
    final reference = NutritionSourceCopy.reference(source);

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
              Text(NutritionSourceCopy.role(source),
                  style: Theme.of(context).textTheme.labelSmall),
              Text(
                NutritionSourceCopy.title(source),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (attribution.isNotEmpty)
                Text(attribution, style: Theme.of(context).textTheme.bodySmall),
              if (location.isNotEmpty)
                Text(location, style: Theme.of(context).textTheme.bodySmall),
              if (source.locator.isNotEmpty &&
                  !NutritionSourceCopy.isInternalPath(source.locator))
                Text(source.locator,
                    style: Theme.of(context).textTheme.bodySmall),
              if (reference.isNotEmpty) NutritionReferenceText(reference),
              if (NutritionSourceCopy.isComposition(source))
                Text(
                    'Dùng để tính thành phần nguyên liệu; không xác nhận công thức này là thực đơn do Viện Dinh dưỡng biên soạn.',
                    style: Theme.of(context).textTheme.bodySmall),
              if (verifiedOn != null)
                Text(
                  'Ngày ghi nhận nguồn: ${formatDate(verifiedOn, padded: true)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
