import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/beneficiary_form_controller.dart';
import 'beneficiary_form_fields.dart';
import 'beneficiary_field_label.dart';
import 'beneficiary_section_header.dart';
import 'beneficiary_condition_input.dart';
import 'beneficiary_notes_field.dart';

class BeneficiaryCareInformation extends ConsumerWidget {
  const BeneficiaryCareInformation(
      {super.key, this.profileId, required this.fields});
  final String? profileId;
  final BeneficiaryFormFields fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = beneficiaryFormControllerProvider(profileId);
    final conditions = ref.watch(provider.select((state) => state.conditions));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const BeneficiarySectionHeader(title: '📋 Thông tin cần biết'),
      BeneficiaryConditionInput(
        controller: fields.condition,
        tags: conditions,
        onAdd: () {
          ref.read(provider.notifier).addCondition(fields.condition.text);
          fields.condition.clear();
        },
        onRemove: ref.read(provider.notifier).removeCondition,
      ),
      const SizedBox(height: AppSpacing.md),
      const BeneficiaryFieldLabel(text: 'Ghi chú đặc biệt cho người chăm sóc'),
      BeneficiaryNotesField(notesCtrl: fields.notes),
      const SizedBox(height: AppSpacing.wide),
    ]);
  }
}
