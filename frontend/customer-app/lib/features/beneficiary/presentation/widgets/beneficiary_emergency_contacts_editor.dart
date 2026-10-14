import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'beneficiary_contact_entry.dart';
import 'beneficiary_section_header.dart';
import 'beneficiary_emergency_contact_notice.dart';
import 'beneficiary_emergency_contact_card.dart';

class BeneficiaryEmergencyContactsEditor extends StatefulWidget {
  const BeneficiaryEmergencyContactsEditor({super.key, required this.contacts});
  final List<BeneficiaryContactEntry> contacts;

  @override
  State<BeneficiaryEmergencyContactsEditor> createState() =>
      _BeneficiaryEmergencyContactsState();
}

class _BeneficiaryEmergencyContactsState
    extends State<BeneficiaryEmergencyContactsEditor> {
  void _remove(BeneficiaryContactEntry entry) {
    if (widget.contacts.length <= 2) return;
    setState(() => widget.contacts.remove(entry));
    // Dispose after the removed TextFields have detached their listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BeneficiarySectionHeader(title: '🚨 Liên hệ khẩn cấp'),
        const BeneficiaryEmergencyContactNotice(),
        for (var index = 0; index < widget.contacts.length; index++)
          BeneficiaryEmergencyContactCard(
            key: ObjectKey(widget.contacts[index]),
            entry: widget.contacts[index],
            index: index,
            onRemove: widget.contacts.length > 2
                ? () => _remove(widget.contacts[index])
                : null,
          ),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => widget.contacts.add(BeneficiaryContactEntry())),
          icon: const Icon(Icons.add),
          label: const Text('Thêm liên hệ khẩn cấp'),
        ),
        const SizedBox(height: AppSpacing.md),
      ]);
}
