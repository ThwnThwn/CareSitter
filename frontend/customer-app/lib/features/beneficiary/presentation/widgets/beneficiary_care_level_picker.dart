import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/beneficiary_form_controller.dart';
import '../models/beneficiary_form_options.dart';

class BeneficiaryCareLevelPicker extends ConsumerWidget {
  const BeneficiaryCareLevelPicker({super.key, this.profileId});
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = beneficiaryFormControllerProvider(profileId);
    final selected = ref.watch(provider.select((state) => state.careLevel));
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: BeneficiaryFormOptions.careLevels.map((level) {
        final color = level == 'Nặng'
            ? AppColors.error
            : level == 'Trung bình'
                ? AppColors.warning
                : AppColors.success;
        return ChoiceChip(
          label: Text(level),
          selected: level == selected,
          selectedColor: color.withValues(alpha: 0.13),
          labelStyle:
              TextStyle(color: level == selected ? color : AppColors.textSecondary),
          onSelected: (_) => ref.read(provider.notifier).careLevel = level,
        );
      }).toList(),
    );
  }
}
