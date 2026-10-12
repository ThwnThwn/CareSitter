import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_contact_entry.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryEditContactCardIndexSelectFamilyContactRow
    extends StatelessWidget {
  const BeneficiaryEditContactCardIndexSelectFamilyContactRow(
      {super.key,
      required this.index,
      required this.selectFamilyContact,
      required this.entry,
      required this.canRemove,
      required this.setState,
      required this.contacts});
  final int index;
  final Future<void> Function(BeneficiaryContactEntry) selectFamilyContact;
  final BeneficiaryContactEntry entry;
  final bool canRemove;
  final void Function(void Function()) setState;
  final List<BeneficiaryContactEntry> contacts;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: Text(
              'Liên hệ khẩn cấp ${index + 1}',
              style: const TextStyle(
                fontSize: AppFontSizes.s14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => selectFamilyContact(entry),
            icon: const Icon(Icons.people_outline, size: 17),
            label: const Text('Danh bạ'),
          ),
          if (canRemove)
            GestureDetector(
              onTap: () => setState(() => contacts.removeAt(index)),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.tight),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.error),
              ),
            ),
        ],
      );
}
