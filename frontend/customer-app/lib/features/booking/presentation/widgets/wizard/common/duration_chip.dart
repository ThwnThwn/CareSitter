import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DurationChip extends StatelessWidget {
  const DurationChip({
    super.key,
    required this.hours,
    required this.selected,
    required this.onTap,
  });

  final int hours;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: 'Chọn thời lượng $hours giờ',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.control),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryContainer
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    const Icon(Icons.check_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    '$hours giờ',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
