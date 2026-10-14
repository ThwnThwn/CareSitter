import 'package:caresitter_customer/core/widgets/gallery_image_picker.dart';
import '../widgets/beneficiary_form_fields.dart';

import '../widgets/beneficiary_profile_form.dart';
import '../controllers/beneficiary_form_controller.dart';

import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_contact_entry.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/widgets/birth_date_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

// Helper: entry cho 1 liên hệ khẩn cấp

class BeneficiaryCreateScreen extends ConsumerStatefulWidget {
  const BeneficiaryCreateScreen({super.key});

  @override
  ConsumerState<BeneficiaryCreateScreen> createState() =>
      _BeneficiaryCreateScreenState();
}

class _BeneficiaryCreateScreenState extends ConsumerState<BeneficiaryCreateScreen> {
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không chọn được ảnh. Vui lòng thử lại.')));
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: AppColors.error));
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

    return BeneficiaryProfileForm(
      fields: _fields,
      formKey: _formKey,
      onPickAvatar: _pickImage,
      onSave: _save,
      hasChanges: () => _hasUnsavedChanges,
    );
  }

}
