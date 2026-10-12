import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_create_contact_card_index_select_family_contact_fields.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_contact_entry.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryCreateContactCardIndexSelectFamilyContactPanel
    extends StatelessWidget {
  const BeneficiaryCreateContactCardIndexSelectFamilyContactPanel(
      {super.key,
      required this.index,
      required this.selectFamilyContact,
      required this.entry,
      required this.canRemove,
      required this.setState,
      required this.contacts,
      required this.saveToFamilyContacts,
      required this.contactRelations,
      required this.action1});
  final int index;
  final Future<void> Function(BeneficiaryContactEntry) selectFamilyContact;
  final BeneficiaryContactEntry entry;
  final bool canRemove;
  final void Function(void Function()) setState;
  final List<BeneficiaryContactEntry> contacts;
  final Future<void> Function(BeneficiaryContactEntry) saveToFamilyContacts;
  final List<String> contactRelations;
  final void Function(String?) action1;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.compact),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: BeneficiaryCreateContactCardIndexSelectFamilyContactFields(
            index: index,
            selectFamilyContact: selectFamilyContact,
            entry: entry,
            canRemove: canRemove,
            setState: setState,
            contacts: contacts,
            contactRelations: contactRelations,
            action1: action1,
            callbackAction1: (v) => (v?.trim().isEmpty ?? true)
                ? 'Vui lòng nhập tên liên hệ'
                : null,
            callbackAction2: (v) {
              if (v?.trim().isEmpty ?? true) {
                return 'Vui lòng nhập số điện thoại';
              }
              if (!RegExp(r'^0[3-9]\d{8}$').hasMatch(v!.trim())) {
                return 'Số điện thoại không hợp lệ';
              }
              return null;
            },
            callbackAction3: () => saveToFamilyContacts(entry)),
      );
}
