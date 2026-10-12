import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_form_controller.dart';
import 'package:flutter/material.dart';

class BeneficiaryCreateGenderField extends StatelessWidget {
  const BeneficiaryCreateGenderField(
      {super.key,
      required this.formController,
      required this.genders,
      required this.action3});
  final BeneficiaryFormController formController;
  final Map<String, String> genders;
  final void Function(String?) action3;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: formController.gender,
        isExpanded: true,
        decoration: const InputDecoration(hintText: 'Chưa cập nhật'),
        items: genders.entries
            .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ))
            .toList(),
        onChanged: action3,
      );
}
