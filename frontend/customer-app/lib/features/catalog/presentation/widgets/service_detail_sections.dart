import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/models/service_detail_profile.dart';
import 'package:flutter/material.dart';

class ServiceTypeBadge extends StatelessWidget {
  const ServiceTypeBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.tight,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: const Text(
          'Chăm sóc phi y tế tại nhà',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
}

class ServiceFacts extends StatelessWidget {
  const ServiceFacts({super.key, required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final hours = service.defaultDurationMinutes / 60;
    final duration = hours == hours.roundToDouble()
        ? '${hours.toInt()} giờ'
        : '${service.defaultDurationMinutes} phút';
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _FactChip(icon: Icons.schedule_rounded, label: 'Ca từ $duration'),
        const _FactChip(
          icon: Icons.verified_user_outlined,
          label: 'Caregiver đã xác minh',
        ),
        const _FactChip(
          icon: Icons.receipt_long_outlined,
          label: 'Có nhật ký chăm sóc',
        ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: AppSpacing.tight),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class ServiceTimeline extends StatelessWidget {
  const ServiceTimeline({super.key, required this.items});

  final List<ServiceDetailTimelineEntry> items;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final entry in items.indexed)
            _TimelineItem(
              item: entry.$2,
              isLast: entry.$1 == items.length - 1,
            ),
        ],
      );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item, required this.isLast});

  final ServiceDetailTimelineEntry item;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimelineRail(item: item, isLast: isLast),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({required this.item, required this.isLast});

  final ServiceDetailTimelineEntry item;
  final bool isLast;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 36,
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer,
              ),
              child: Icon(item.icon, size: 17, color: AppColors.primary),
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

class IncludedTasks extends StatelessWidget {
  const IncludedTasks({super.key, required this.tasks});

  final List<String> tasks;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Công việc có trong gói',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.compact),
              for (final task in tasks) _IncludedTaskRow(task: task),
            ],
          ),
        ),
      );
}

class _IncludedTaskRow extends StatelessWidget {
  const _IncludedTaskRow({required this.task});

  final String task;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.tight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.control),
            Expanded(
              child: Text(
                task,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                    ),
              ),
            ),
          ],
        ),
      );
}

class SafetyCommitment extends StatelessWidget {
  const SafetyCommitment({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Cam kết CareSitter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.compact),
            const Text(
              'Caregiver được xác minh hồ sơ • Giá và phạm vi công việc minh bạch • Gia đình theo dõi nhật ký ca chăm sóc.',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Dịch vụ không thay thế khám, chẩn đoán, điều trị hoặc thực hiện thủ thuật y tế.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
}
