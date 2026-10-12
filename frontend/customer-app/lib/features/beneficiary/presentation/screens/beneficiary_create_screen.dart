import 'package:caresitter_customer/core/widgets/gallery_image_picker.dart';
import '../widgets/beneficiary_form_fields.dart';
import '../models/beneficiary_form_options.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_create_form.dart';
import '../controllers/beneficiary_form_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_create_screen_section_header.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_create_screen_tag_input.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_create_contact_card_index_select_family_contact_panel.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_contact_entry.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/widgets/birth_date_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/family_contact_controller.dart';
import 'package:caresitter_customer/core/widgets/family_contact_picker.dart';

// Helper: entry cho 1 liên hệ khẩn cấp

class BeneficiaryCreateScreen extends ConsumerStatefulWidget {
  const BeneficiaryCreateScreen({super.key});

  @override
  ConsumerState<BeneficiaryCreateScreen> createState() =>
      _BeneficiaryCreateScreenState();
}

class _BeneficiaryCreateScreenState
    extends ConsumerState<BeneficiaryCreateScreen> {
  late BeneficiaryFormController _formController;
  ProviderSubscription<BeneficiaryFormController>? _formSubscription;
  void _bindController() {
    _formSubscription?.close();
    final provider = beneficiaryFormControllerProvider(null);
    _formController = ref.read(provider.notifier);
    _formSubscription = ref.listenManual(provider.notifier, (_, controller) {
      _formController = controller;
    });
  }

  final _formKey = GlobalKey<FormState>();

  // Thông tin cơ bản
  final _fields = BeneficiaryFormFields();
  TextEditingController get _nameCtrl => _fields.name;
  TextEditingController get _birthDateCtrl => _fields.birthDate;
  XFile? _avatarFile;

  // Thông tin cần biết (tag-based)
  TextEditingController get _conditionCtrl => _fields.condition;

  // Ghi chú
  TextEditingController get _notesCtrl => _fields.notes;

  // Liên hệ khẩn cấp (tối thiểu 2)
  List<BeneficiaryContactEntry> get _contacts => _fields.contacts;

  bool get _hasUnsavedChanges =>
      _nameCtrl.text.trim().isNotEmpty ||
      _birthDateCtrl.text.trim().isNotEmpty ||
      _formController.addressId != null ||
      _conditionCtrl.text.trim().isNotEmpty ||
      _formController.value.conditions.isNotEmpty ||
      _notesCtrl.text.trim().isNotEmpty ||
      _formController.gender != null ||
      _formController.relation != 'Bố' ||
      _formController.careLevel != 'Nhẹ' ||
      _formController.avatarPath != null ||
      _contacts.length != 2 ||
      _contacts.any(
        (entry) =>
            entry.nameCtrl.text.trim().isNotEmpty ||
            entry.phoneCtrl.text.trim().isNotEmpty ||
            entry.relationship != 'Con trai',
      );

  Future<void> _pickImage() async {
    try {
      final image = await GalleryImagePicker.pick();
      if (image != null && mounted) {
        setState(() {
          _avatarFile = image;
          _formController.avatarPath = image.path;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không chọn được ảnh. Vui lòng thử lại.')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _bindController();
  }

  @override
  void dispose() {
    _formSubscription?.close();
    _fields.dispose();
    super.dispose();
  }

  void _addTag(TextEditingController ctrl, List<String> list) {
    final val = ctrl.text.trim();
    if (val.isNotEmpty && !list.contains(val)) {
      _formController.addCondition(val);
      ctrl.clear();
    }
  }

  Future<void> _selectFamilyContact(BeneficiaryContactEntry entry) async {
    final contact = await pickFamilyContact(context, ref,
        provider: familyContactsProvider,
        name: (c) => c.fullName,
        phone: (c) => c.phoneNumber);
    if (contact == null || !mounted) return;
    setState(() {
      entry.nameCtrl.text = contact.fullName;
      entry.phoneCtrl.text = contact.phoneNumber;
    });
  }

  Future<void> _saveToFamilyContacts(BeneficiaryContactEntry entry) async {
    final name = entry.nameCtrl.text.trim();
    final phone = entry.phoneCtrl.text.trim();
    if (name.isEmpty || !RegExp(r'^0[3-9]\d{8}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nhập họ tên và số điện thoại hợp lệ trước khi lưu.'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    try {
      await ref.read(familyContactsProvider.notifier).add(
            fullName: name,
            phoneNumber: phone,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã lưu vào danh bạ gia đình.'),
            backgroundColor: AppColors.success),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Không lưu được liên hệ. Số này có thể đã tồn tại.'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await _formController.save(
      name: _nameCtrl.text,
      birthDate: BirthDateField.parse(_birthDateCtrl.text),
      notes: _notesCtrl.text,
      contacts: [
        for (final c in _contacts)
          EmergencyContact(
              name: c.nameCtrl.text.trim(),
              phone: c.phoneCtrl.text.trim(),
              relationship: c.relationship)
      ],
      avatar: _avatarFile,
    );
    if (!mounted) return;
    if (result is BeneficiaryFormMessage) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message), backgroundColor: AppColors.error));
    } else if (result is BeneficiaryFormSaved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Đã thêm hồ sơ người thân thành công!'),
          backgroundColor: AppColors.success));
      if (context.canPop()) {
        context.pop(result.id);
      } else {
        context.go('/beneficiaries');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(beneficiaryFormControllerProvider(null));
    return BeneficiaryCreateForm(
        formController: _formController,
        save: _save,
        formKey: _formKey,
        pickImage: _pickImage,
        buildSectionHeader: _buildSectionHeader,
        buildLabel: _buildLabel,
        nameCtrl: _nameCtrl,
        birthDateCtrl: _birthDateCtrl,
        genders: BeneficiaryFormOptions.genders,
        buildDropdown: _buildDropdown,
        relations: BeneficiaryFormOptions.relations,
        careLevels: BeneficiaryFormOptions.careLevels,
        buildTagInput: _buildTagInput,
        conditionCtrl: _conditionCtrl,
        notesCtrl: _notesCtrl,
        contacts: _contacts,
        buildContactCard: _buildContactCard,
        action1: () => _hasUnsavedChanges,
        action2: (v) =>
            (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập tên' : null,
        action3: (value) => setState(() => _formController.gender = value),
        action4: (v) => setState(() => _formController.relation = v!),
        action5: (address) =>
            setState(() => _formController.addressId = address.id),
        action6: (value) => setState(() => _formController.careLevel = value),
        action7: () =>
            setState(() => _contacts.add(BeneficiaryContactEntry())));
  }

  // ── Widgets phụ ──────────────────────────────────────────────

  Widget _buildSectionHeader(String title) =>
      BeneficiaryCreateScreenSectionHeader(title: title);

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.tight),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: AppFontSizes.s13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildDropdown(
      List<String> items, String value, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(),
      items:
          items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTagInput({
    required String label,
    required String hint,
    required TextEditingController ctrl,
    required List<String> tags,
    required Color tagColor,
  }) =>
      BeneficiaryCreateScreenTagInput(
          removeTag: _formController.removeCondition,
          buildLabel: _buildLabel,
          label: label,
          ctrl: ctrl,
          hint: hint,
          addTag: _addTag,
          tags: tags,
          setState: setState,
          tagColor: tagColor);

  Widget _buildContactCard(int index, BeneficiaryContactEntry entry) {
    final canRemove = _contacts.length > 2;
    return BeneficiaryCreateContactCardIndexSelectFamilyContactPanel(
        index: index,
        selectFamilyContact: _selectFamilyContact,
        entry: entry,
        canRemove: canRemove,
        setState: setState,
        contacts: _contacts,
        saveToFamilyContacts: _saveToFamilyContacts,
        contactRelations: BeneficiaryFormOptions.contactRelations,
        action1: (v) => setState(() => entry.relationship = v!));
  }
}
