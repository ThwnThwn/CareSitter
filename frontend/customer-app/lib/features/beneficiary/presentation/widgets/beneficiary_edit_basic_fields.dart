import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_edit_care_level_fields.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_edit_gender_field.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_form_controller.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/widgets/birth_date_field.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/verified_beneficiary_address_picker.dart';
import 'package:caresitter_customer/features/catalog/data/models/address_model.dart';

class BeneficiaryEditBasicFields extends StatelessWidget {
  const BeneficiaryEditBasicFields(
      {super.key,
      required this.formController,
      required this.buildSectionHeader,
      required this.buildLabel,
      required this.nameCtrl,
      required this.birthDateCtrl,
      required this.genders,
      required this.buildDropdown,
      required this.relations,
      required this.careLevels,
      required this.action2,
      required this.action3,
      required this.action4,
      required this.action5,
      required this.action6});
  final BeneficiaryFormController formController;
  final Widget Function(String) buildSectionHeader;
  final Widget Function(String) buildLabel;
  final TextEditingController nameCtrl;
  final TextEditingController birthDateCtrl;
  final Map<String, String> genders;
  final Widget Function(List<String>, String, void Function(String?))
      buildDropdown;
  final List<String> relations;
  final List<String> careLevels;
  final String? Function(String?) action2;
  final void Function(String?) action3;
  final void Function(String?) action4;
  final void Function(AddressModel) action5;
  final void Function(String) action6;
  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            buildSectionHeader('👤 Thông tin cơ bản'),
            buildLabel('Họ và tên *'),
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Nhập họ tên đầy đủ'),
              validator: action2,
            ),
            const SizedBox(height: AppSpacing.md),
            BirthDateField(controller: birthDateCtrl),
            const SizedBox(height: AppSpacing.md),
            buildLabel('Giới tính'),
            BeneficiaryEditGenderField(
                formController: formController,
                genders: genders,
                action3: action3),
            const SizedBox(height: AppSpacing.md),
            buildLabel('Quan hệ với bạn'),
            if (formController.value.isSelf)
              const Text('Bản thân')
            else
              buildDropdown([
                if (!relations.contains(formController.relation))
                  formController.relation,
                ...relations
              ], formController.relation, action4),
            const SizedBox(height: AppSpacing.md),
            buildLabel('Địa chỉ chăm sóc *'),
            VerifiedBeneficiaryAddressPicker(
              selectedAddressId: formController.addressId,
              onChanged: action5,
            ),
            const SizedBox(height: AppSpacing.md),
            buildLabel('Mức độ chăm sóc'),
            BeneficiaryEditCareLevelFields(
                careLevels: careLevels,
                formController: formController,
                action6: action6),
            const SizedBox(height: AppSpacing.wide),
          ]);
}
