import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';

class NutritionPlanSetupSheet extends StatefulWidget {
  const NutritionPlanSetupSheet({
    super.key,
    required this.startDate,
    this.beneficiaryName,
  });

  final DateTime startDate;
  final String? beneficiaryName;

  @override
  State<NutritionPlanSetupSheet> createState() =>
      _NutritionPlanSetupSheetState();
}

class _NutritionPlanSetupSheetState extends State<NutritionPlanSetupSheet> {
  int _days = 5;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.section,
            AppSpacing.compact,
            AppSpacing.section,
            AppSpacing.section + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: AppSpacing.md),
              const _PlanSetupHeader(),
              const SizedBox(height: AppSpacing.md),
              if (widget.beneficiaryName?.trim().isNotEmpty == true)
                _ContextCard(
                  icon: Icons.person_outline_rounded,
                  label: 'Người được chăm sóc',
                  value: widget.beneficiaryName!.trim(),
                ),
              if (widget.beneficiaryName?.trim().isNotEmpty == true)
                const SizedBox(height: AppSpacing.compact),
              _DurationSection(
                selectedDays: _days,
                onSelected: (days) => setState(() => _days = days),
              ),
              const SizedBox(height: AppSpacing.md),
              _ContextCard(
                icon: Icons.calendar_today_outlined,
                label: 'Bắt đầu từ ngày',
                value: formatDate(widget.startDate, padded: true),
              ),
              const SizedBox(height: AppSpacing.compact),
              _PlanSummary(days: _days),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('nutrition-create-plan-submit'),
                  onPressed: () => Navigator.of(context).pop(_days),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text('Tạo thực đơn $_days ngày'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      );
}

class _PlanSetupHeader extends StatelessWidget {
  const _PlanSetupHeader();

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tạo thực đơn dinh dưỡng',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text('Chọn khoảng thời gian phù hợp để bắt đầu.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
}

class _DurationSection extends StatelessWidget {
  const _DurationSection({
    required this.selectedDays,
    required this.onSelected,
  });

  final int selectedDays;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Khoảng thời gian',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in const [
                (3, 'Dùng thử'),
                (5, 'Khuyên dùng'),
                (7, 'Cả tuần')
              ])
                _DurationChoice(
                  days: option.$1,
                  caption: option.$2,
                  selected: selectedDays == option.$1,
                  onTap: () => onSelected(option.$1),
                ),
            ],
          ),
        ],
      );
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.compact),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Text(
          'Mỗi ngày gồm bữa sáng, trưa và tối · Tổng cộng ${days * 3} bữa.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}

class _DurationChoice extends StatelessWidget {
  const _DurationChoice({
    required this.days,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final int days;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: '$days ngày, $caption',
        child: InkWell(
          key: ValueKey('nutrition-plan-days-$days'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 104,
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.all(AppSpacing.compact),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryContainer
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.primary),
                Text(
                  '$days ngày',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(caption, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      );
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.compact),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
