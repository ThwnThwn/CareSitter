import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_dropdown_field.dart';
import 'package:flutter/material.dart';

/// Dropdown field theo Stitch design:
/// card trắng bo tròn 16px, label uppercase, icon status + shadow nhẹ.
class NutritionStatusField extends StatelessWidget {
  const NutritionStatusField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    assert(options.isNotEmpty, 'NutritionStatusField requires options.');
    final effectiveValue = options.containsKey(value)
        ? value
        : options.containsKey('unknown')
            ? 'unknown'
            : options.keys.first;
    final isConfirmed = effectiveValue == 'reported_none' ||
        effectiveValue == 'reported_present';

    return _StatusCard(
      label: label,
      value: effectiveValue,
      options: options,
      enabled: enabled,
      isConfirmed: isConfirmed,
      onChanged: onChanged,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.value,
    required this.options,
    required this.enabled,
    required this.isConfirmed,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final bool enabled;
  final bool isConfirmed;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label uppercase brand color
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _StatusSelector(
              value: value,
              options: options,
              enabled: enabled,
              isConfirmed: isConfirmed,
              onChanged: onChanged,
            ),
          ],
        ),
      );
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.value,
    required this.options,
    required this.enabled,
    required this.isConfirmed,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final bool enabled;
  final bool isConfirmed;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isConfirmed
                  ? AppColors.primaryContainer
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConfirmed ? Icons.check : Icons.help_outline,
              size: 12,
              color: isConfirmed ? AppColors.primary : AppColors.textHint,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatusDropdown(
              value: value,
              options: options,
              enabled: enabled,
              onChanged: onChanged,
            ),
          ),
        ],
      );
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> options;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          focusColor: AppColors.primaryContainer,
          hoverColor: AppColors.surfaceVariant,
          highlightColor: Colors.transparent,
          splashColor: AppColors.primaryContainer,
        ),
        child: AppDropdownField<String>(
          initialValue: value,
          isExpanded: true,
          selectedItemBuilder: (_) => options.values
              .map((label) => Text(label, overflow: TextOverflow.ellipsis))
              .toList(),
          items: options.entries
              .map((entry) => DropdownMenuItem(
                    value: entry.key,
                    child: _DropdownOption(
                      label: entry.value,
                      selected: entry.key == value,
                    ),
                  ))
              .toList(),
          enabled: enabled,
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}

class _DropdownOption extends StatelessWidget {
  const _DropdownOption({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.compact),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.check_rounded,
                  size: 18, color: AppColors.primary),
            ],
          ],
        ),
      );
}
