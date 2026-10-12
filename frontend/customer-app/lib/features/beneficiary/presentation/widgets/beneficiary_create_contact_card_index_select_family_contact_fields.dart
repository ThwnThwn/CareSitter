import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_create_contact_card_index_select_family_contact_row.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_contact_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryCreateContactCardIndexSelectFamilyContactFields
    extends StatelessWidget {
  const BeneficiaryCreateContactCardIndexSelectFamilyContactFields(
      {super.key,
      required this.index,
      required this.selectFamilyContact,
      required this.entry,
      required this.canRemove,
      required this.setState,
      required this.contacts,
      required this.contactRelations,
      required this.action1,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3});
  final int index;
  final Future<void> Function(BeneficiaryContactEntry) selectFamilyContact;
  final BeneficiaryContactEntry entry;
  final bool canRemove;
  final void Function(void Function()) setState;
  final List<BeneficiaryContactEntry> contacts;
  final List<String> contactRelations;
  final void Function(String?) action1;
  final String? Function(String?) callbackAction1;
  final String? Function(String?) callbackAction2;
  final void Function() callbackAction3;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          BeneficiaryCreateContactCardIndexSelectFamilyContactRow(
              index: index,
              selectFamilyContact: selectFamilyContact,
              entry: entry,
              canRemove: canRemove,
              setState: setState,
              contacts: contacts),
          const SizedBox(height: AppSpacing.inset),

          // Tên
          TextFormField(
            controller: entry.nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Họ tên *',
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
            validator: callbackAction1,
          ),
          const SizedBox(height: AppSpacing.control),

          // Số điện thoại
          TextFormField(
            controller: entry.phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: const InputDecoration(
              labelText: 'Số điện thoại *',
              prefixIcon: Icon(Icons.phone_outlined, size: 18),
              hintText: '0909 123 456',
            ),
            validator: callbackAction2,
          ),
          const SizedBox(height: AppSpacing.control),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: callbackAction3,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
              label: const Text('Lưu vào danh bạ gia đình'),
            ),
          ),
          const SizedBox(height: AppSpacing.micro),

          // Mối quan hệ
          DropdownButtonFormField<String>(
            initialValue: entry.relationship,
            decoration: const InputDecoration(
              labelText: 'Mối quan hệ',
              prefixIcon: Icon(Icons.family_restroom_outlined, size: 18),
            ),
            items: contactRelations
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: action1,
          ),
        ],
      );
}
