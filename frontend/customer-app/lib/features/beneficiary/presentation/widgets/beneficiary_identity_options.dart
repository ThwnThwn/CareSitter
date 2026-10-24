import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_dropdown_field.dart';
import '../controllers/beneficiary_form_controller.dart';
import '../models/beneficiary_form_options.dart';
import 'beneficiary_field_label.dart';

class BeneficiaryIdentityOptions extends ConsumerWidget {
  const BeneficiaryIdentityOptions({super.key, this.profileId});
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = beneficiaryFormControllerProvider(profileId);
    final draft = ref.watch(provider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const BeneficiaryFieldLabel(text: 'Giới tính'),
      AppDropdownField<String>(
        initialValue: draft.gender,
        isExpanded: true,
        decoration: const InputDecoration(hintText: 'Chưa cập nhật'),
        items: BeneficiaryFormOptions.genders.entries
            .map((entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)))
            .toList(),
        onChanged: (value) => ref.read(provider.notifier).gender = value,
      ),
      const SizedBox(height: AppSpacing.md),
      const BeneficiaryFieldLabel(text: 'Quan hệ với bạn'),
      if (draft.isSelf)
        const Text('Bản thân')
      else
        AppDropdownField<String>(
          initialValue: draft.relation,
          isExpanded: true,
          items: [
            if (!BeneficiaryFormOptions.relations.contains(draft.relation))
              draft.relation,
            ...BeneficiaryFormOptions.relations,
          ]
              .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) {
            if (value != null) ref.read(provider.notifier).relation = value;
          },
        ),
    ]);
  }
}
