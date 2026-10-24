import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_checklist_item_model.dart';
import 'package:flutter/material.dart';

class ServiceChecklistSection extends StatelessWidget {
  const ServiceChecklistSection({
    super.key,
    required this.items,
    required this.loading,
    required this.onRetry,
    this.error,
  });

  final List<ServiceChecklistItemModel> items;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Công việc có trong gói',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Checklist được quản trị theo gói và lưu lại khi xác nhận booking.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (loading)
            const _ChecklistLoading()
          else if (error != null)
            _ChecklistError(onRetry: onRetry)
          else if (items.isEmpty)
            const _ChecklistEmpty()
          else
            for (final entry in items.indexed)
              _ChecklistItem(
                item: entry.$2,
                isLast: entry.$1 == items.length - 1,
              ),
        ],
      );
}

class _ChecklistLoading extends StatelessWidget {
  const _ChecklistLoading();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
}

class _ChecklistError extends StatelessWidget {
  const _ChecklistError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Text('Chưa tải được checklist của gói.'),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      );
}

class _ChecklistEmpty extends StatelessWidget {
  const _ChecklistEmpty();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Gói này chưa có checklist công việc được công bố.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.item, required this.isLast});

  final ServiceChecklistItemModel item;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChecklistRail(isLast: isLast),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: isLast ? 0 : AppSpacing.lg,
                ),
                child: _ChecklistItemContent(item: item),
              ),
            ),
          ],
        ),
      );
}

class _ChecklistRail extends StatelessWidget {
  const _ChecklistRail({required this.isLast});

  final bool isLast;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 36,
        child: Column(
          children: [
            const SizedBox.square(
              dimension: 30,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (!isLast)
              const Expanded(
                child: VerticalDivider(
                  color: AppColors.border,
                  thickness: 1.5,
                  width: 1.5,
                ),
              ),
          ],
        ),
      );
}

class _ChecklistItemContent extends StatelessWidget {
  const _ChecklistItemContent({required this.item});

  final ServiceChecklistItemModel item;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (item.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.description!.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
          ],
          if (item.isRequired || item.requiresPhoto) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (item.isRequired) const _TaskMeta(label: 'Bắt buộc'),
                if (item.requiresPhoto) const _TaskMeta(label: 'Cần ảnh'),
              ],
            ),
          ],
        ],
      );
}

class _TaskMeta extends StatelessWidget {
  const _TaskMeta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
