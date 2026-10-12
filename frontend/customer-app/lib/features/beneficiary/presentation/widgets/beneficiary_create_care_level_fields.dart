import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_form_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_create_care_level_choice.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryCreateCareLevelFields extends StatelessWidget {
  const BeneficiaryCreateCareLevelFields(
      {super.key,
      required this.careLevels,
      required this.formController,
      required this.action6});
  final List<String> careLevels;
  final BeneficiaryFormController formController;
  final void Function(String) action6;

  @override
  Widget build(BuildContext context) => Row(
        children: careLevels.map((level) {
          final isSelected = level == formController.careLevel;
          final color = level == 'Nặng'
              ? AppColors.error
              : level == 'Trung bình'
                  ? AppColors.warning
                  : AppColors.success;
          return BeneficiaryCreateCareLevelChoice(
              onSelected: action6,
              level: level,
              isSelected: isSelected,
              color: color);
        }).toList(),
      );
}
