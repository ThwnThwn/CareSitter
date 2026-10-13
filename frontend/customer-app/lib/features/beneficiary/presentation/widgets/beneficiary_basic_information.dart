import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/birth_date_field.dart';
import '../controllers/beneficiary_form_controller.dart';
import 'beneficiary_form_fields.dart';
import 'beneficiary_field_label.dart';
import 'beneficiary_section_header.dart';
import 'beneficiary_identity_options.dart';
import 'beneficiary_care_level_picker.dart';
import 'verified_beneficiary_address_picker.dart';

class BeneficiaryBasicInformation extends ConsumerWidget {
  const BeneficiaryBasicInformation(
      {super.key, this.profileId, required this.fields});
  final String? profileId;
  final BeneficiaryFormFields fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = beneficiaryFormControllerProvider(profileId);
    final draft = ref.watch(provider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const BeneficiarySectionHeader(title: '👤 Thông tin cơ bản'),
      const BeneficiaryFieldLabel(text: 'Họ và tên *'),
      TextFormField(
        controller: fields.name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Nhập họ tên đầy đủ'),
        validator: (value) =>
            (value?.trim().isEmpty ?? true) ? 'Vui lòng nhập tên' : null,
      ),
      const SizedBox(height: AppSpacing.md),
      BirthDateField(controller: fields.birthDate),
      const SizedBox(height: AppSpacing.md),
      BeneficiaryIdentityOptions(profileId: profileId),
      const SizedBox(height: AppSpacing.md),
      const BeneficiaryFieldLabel(text: 'Địa chỉ chăm sóc *'),
      VerifiedBeneficiaryAddressPicker(
        selectedAddressId: draft.addressId,
        onChanged: (address) => ref.read(provider.notifier).addressId = address.id,
      ),
      const SizedBox(height: AppSpacing.md),
      const BeneficiaryFieldLabel(text: 'Mức độ chăm sóc'),
      BeneficiaryCareLevelPicker(profileId: profileId),
      const SizedBox(height: AppSpacing.wide),
    ]);
  }
}
