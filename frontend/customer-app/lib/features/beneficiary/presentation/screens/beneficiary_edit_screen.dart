import 'package:caresitter_customer/core/widgets/gallery_image_picker.dart';
import '../widgets/beneficiary_form_fields.dart';

import '../widgets/beneficiary_profile_form.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_edit_missing_state.dart';
import '../controllers/beneficiary_form_controller.dart';

import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_contact_entry.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/widgets/birth_date_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

// Helper: entry cho 1 liên hệ khẩn cấp

class BeneficiaryEditScreen extends ConsumerStatefulWidget {
  final String id;
  const BeneficiaryEditScreen({super.key, required this.id});

  @override
  ConsumerState<BeneficiaryEditScreen> createState() =>
      _BeneficiaryEditScreenState();
}

class _BeneficiaryEditScreenState extends ConsumerState<BeneficiaryEditScreen> {
  late BeneficiaryFormController _formController;
  ProviderSubscription<BeneficiaryFormController>? _formSubscription;
  void _bindController() {
    _formSubscription?.close();
    final provider = beneficiaryFormControllerProvider(widget.id);
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

  // Ghi chú
  TextEditingController get _notesCtrl => _fields.notes;

  // Liên hệ khẩn cấp (tối thiểu 2)
  List<BeneficiaryContactEntry> get _contacts => _fields.contacts;

  String? _loadedProfileId;
  String _initialFormState = '';

  String get _formState => _fields.fingerprint(_formController.value);

  @override
  void initState() {
    super.initState();
    _bindController();
    _loadProfile(ref.read(beneficiaryStoreProvider));
    ref.listenManual(beneficiaryStoreProvider, (_, profiles) {
      if (_loadedProfileId != widget.id &&
          profiles.any((b) => b.id == widget.id)) {
        setState(() => _loadProfile(profiles));
      }
    });
  }

  @override
  void didUpdateWidget(covariant BeneficiaryEditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _bindController();
      _loadProfile(ref.read(beneficiaryStoreProvider));
    }
  }

  void _loadProfile(List<BeneficiaryModel> beneficiaries) {
    final b = beneficiaries.where((e) => e.id == widget.id).firstOrNull;
    if (b == null) {
      _initialFormState = _formState;
      return;
    }
    _avatarFile = null;
    _fields.load(b);
    _loadedProfileId = widget.id;
    _initialFormState = _formState;
  }

  @override
  void dispose() {
    _formSubscription?.close();
    _fields.dispose();
    super.dispose();
  }

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
          content: Text('Đã cập nhật hồ sơ người thân.'),
          backgroundColor: AppColors.success));
      popOrGo(context, fallbackRoute: AppRoutes.beneficiaryDetail(widget.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(beneficiaryFormControllerProvider(widget.id));
    final profileExists =
        ref.watch(beneficiaryStoreProvider).any((b) => b.id == widget.id);
    if (!_formController.value.profileFound || !profileExists) {
      return const BeneficiaryEditMissingState();
    }
    return BeneficiaryProfileForm(
      profileId: widget.id,
      fields: _fields,
      formKey: _formKey,
      onPickAvatar: _pickImage,
      onSave: _save,
      hasChanges: () => _formState != _initialFormState,
    );
  }
}
