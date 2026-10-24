import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_dropdown_field.dart';
import '../../domain/beneficiary_form_rules.dart';
import '../models/beneficiary_form_options.dart';
import 'beneficiary_contact_entry.dart';

class BeneficiaryEmergencyContactFields extends StatelessWidget {
  const BeneficiaryEmergencyContactFields({super.key, required this.entry});
  final BeneficiaryContactEntry entry;

  @override
  Widget build(BuildContext context) => Column(children: [
        TextFormField(
          controller: entry.nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Họ tên *',
              prefixIcon: Icon(Icons.person_outline, size: 18)),
          validator: beneficiaryContactNameError,
        ),
        const SizedBox(height: AppSpacing.control),
        TextFormField(
          controller: entry.phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11)
          ],
          decoration: const InputDecoration(
              labelText: 'Số điện thoại *',
              prefixIcon: Icon(Icons.phone_outlined, size: 18),
              hintText: '0909 123 456'),
          validator: beneficiaryContactPhoneError,
        ),
        const SizedBox(height: AppSpacing.control),
        AppDropdownField<String>(
          initialValue: entry.relationship,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Mối quan hệ',
              prefixIcon: Icon(Icons.family_restroom_outlined, size: 18)),
          items: [
            if (!BeneficiaryFormOptions.contactRelations
                .contains(entry.relationship))
              entry.relationship,
            ...BeneficiaryFormOptions.contactRelations,
          ]
              .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) {
            if (value != null) entry.relationship = value;
          },
        ),
      ]);
}
