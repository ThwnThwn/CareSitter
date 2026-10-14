import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/family_contact_picker.dart';
import '../../domain/beneficiary_form_rules.dart';
import '../controllers/family_contact_controller.dart';
import 'beneficiary_contact_entry.dart';
import 'beneficiary_emergency_contact_fields.dart';

class BeneficiaryEmergencyContactCard extends ConsumerStatefulWidget {
  const BeneficiaryEmergencyContactCard({
    super.key,
    required this.entry,
    required this.index,
    this.onRemove,
  });
  final BeneficiaryContactEntry entry;
  final int index;
  final VoidCallback? onRemove;

  @override
  ConsumerState<BeneficiaryEmergencyContactCard> createState() =>
      _BeneficiaryEmergencyContactCardState();
}

class _BeneficiaryEmergencyContactCardState
    extends ConsumerState<BeneficiaryEmergencyContactCard> {
  bool _saving = false;

  Future<void> _pickContact() async {
    final contact = await pickFamilyContact(context, ref,
        provider: familyContactsProvider,
        name: (item) => item.fullName,
        phone: (item) => item.phoneNumber);
    if (contact == null || !mounted) return;
    widget.entry.nameCtrl.text = contact.fullName;
    widget.entry.phoneCtrl.text = contact.phoneNumber;
  }

  Future<void> _saveContact() async {
    if (_saving) return;
    final name = widget.entry.nameCtrl.text.trim();
    final phone = widget.entry.phoneCtrl.text.trim();
    if (beneficiaryContactNameError(name) != null ||
        beneficiaryContactPhoneError(phone) != null) {
      _message('Nhập họ tên và số điện thoại hợp lệ trước khi lưu.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(familyContactsProvider.notifier)
          .add(fullName: name, phoneNumber: phone);
      if (mounted) _message('Đã lưu vào danh bạ gia đình.');
    } catch (_) {
      if (mounted) {
        _message('Không lưu được liên hệ. Số này có thể đã tồn tại.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(value),
            backgroundColor: error ? AppColors.error : AppColors.success),
      );

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
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Liên hệ khẩn cấp ${widget.index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Wrap(alignment: WrapAlignment.end, children: [
            TextButton.icon(
                onPressed: _pickContact,
                icon: const Icon(Icons.people_outline, size: 17),
                label: const Text('Danh bạ')),
            if (widget.onRemove != null)
              IconButton(
                onPressed: widget.onRemove,
                tooltip: 'Xóa liên hệ khẩn cấp ${widget.index + 1}',
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
          ]),
          const SizedBox(height: AppSpacing.inset),
          BeneficiaryEmergencyContactFields(entry: widget.entry),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : _saveContact,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
                label: Text(_saving ? 'Đang lưu…' : 'Lưu vào danh bạ gia đình'),
              )),
        ]),
      );
}
