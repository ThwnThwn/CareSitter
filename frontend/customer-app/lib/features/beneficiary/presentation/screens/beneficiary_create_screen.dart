import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/family_contact_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_avatar_image.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/family_contact_picker.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/verified_beneficiary_address_picker.dart';

// Helper: entry cho 1 liên hệ khẩn cấp
class _ECEntry {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  String relationship = 'Con trai';

  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
  }
}

class BeneficiaryCreateScreen extends ConsumerStatefulWidget {
  const BeneficiaryCreateScreen({super.key});

  @override
  ConsumerState<BeneficiaryCreateScreen> createState() =>
      _BeneficiaryCreateScreenState();
}

class _BeneficiaryCreateScreenState
    extends ConsumerState<BeneficiaryCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // Thông tin cơ bản
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  AddressModel? _selectedAddress;
  String _gender = 'Nam';
  String _relation = 'Bố';
  String _careLevel = 'Nhẹ';
  String? _avatarPath;
  XFile? _avatarFile;

  // Thông tin cần biết (tag-based)
  final _conditionCtrl = TextEditingController();
  final List<String> _conditions = [];

  // Ghi chú
  final _notesCtrl = TextEditingController();

  // Liên hệ khẩn cấp (tối thiểu 2)
  final List<_ECEntry> _contacts = [_ECEntry(), _ECEntry()];

  bool _isSaving = false;

  bool get _hasUnsavedChanges =>
      _nameCtrl.text.trim().isNotEmpty ||
      _ageCtrl.text.trim().isNotEmpty ||
      _selectedAddress != null ||
      _conditionCtrl.text.trim().isNotEmpty ||
      _conditions.isNotEmpty ||
      _notesCtrl.text.trim().isNotEmpty ||
      _gender != 'Nam' ||
      _relation != 'Bố' ||
      _careLevel != 'Nhẹ' ||
      _avatarPath != null ||
      _contacts.length != 2 ||
      _contacts.any(
        (entry) =>
            entry.nameCtrl.text.trim().isNotEmpty ||
            entry.phoneCtrl.text.trim().isNotEmpty ||
            entry.relationship != 'Con trai',
      );

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _avatarFile = image;
          _avatarPath = image.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Lỗi chọn ảnh: $e')),
      );
    }
  }

  static const _relations = [
    'Bố',
    'Mẹ',
    'Ông',
    'Bà',
    'Vợ/Chồng',
    'Anh/Chị/Em',
    'Con',
    'Khác'
  ];
  static const _genders = ['Nam', 'Nữ', 'Khác'];
  static const _careLevels = ['Nhẹ', 'Trung bình', 'Nặng'];
  static const _contactRelations = [
    'Con trai',
    'Con gái',
    'Vợ',
    'Chồng',
    'Anh/Chị/Em',
    'Bố/Mẹ',
    'Bạn bè',
    'Người thân',
    'Khác'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _conditionCtrl.dispose();
    _notesCtrl.dispose();
    for (final e in _contacts) {
      e.dispose();
    }
    super.dispose();
  }

  void _addTag(TextEditingController ctrl, List<String> list) {
    final val = ctrl.text.trim();
    if (val.isNotEmpty && !list.contains(val)) {
      setState(() => list.add(val));
      ctrl.clear();
    }
  }

  Future<void> _selectFamilyContact(_ECEntry entry) async {
    final contact = await pickFamilyContact(context, ref);
    if (contact == null || !mounted) return;
    setState(() {
      entry.nameCtrl.text = contact.fullName;
      entry.phoneCtrl.text = contact.phoneNumber;
    });
  }

  Future<void> _saveToFamilyContacts(_ECEntry entry) async {
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
    if (_contacts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cần ít nhất 2 liên hệ khẩn cấp'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn địa chỉ đã xác minh.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final phoneNumbers = _contacts
        .map((entry) => entry.phoneCtrl.text.trim())
        .where((phone) => phone.isNotEmpty);
    if (phoneNumbers.toSet().length != phoneNumbers.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Các liên hệ khẩn cấp không được trùng số điện thoại.'),
            backgroundColor: AppColors.error),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(beneficiaryStoreProvider.notifier).add(
            name: _nameCtrl.text,
            age: int.parse(_ageCtrl.text),
            relation: _relation,
            condition: _conditions.join(', '),
            careLevel: _careLevel,
            notes: _notesCtrl.text,
            defaultAddress: _selectedAddress!,
            emergencyContacts: _contacts
                .map(
                  (entry) => EmergencyContact(
                    name: entry.nameCtrl.text.trim(),
                    phone: entry.phoneCtrl.text.trim(),
                    relationship: entry.relationship,
                  ),
                )
                .toList(growable: false),
            avatarFile: _avatarFile,
          );

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã thêm hồ sơ người thân thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      popOrGo(context, fallbackRoute: '/beneficiaries');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thêm được người thân. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _hasUnsavedChanges,
      fallbackRoute: '/beneficiaries',
      builder: (context, requestExit) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Thêm người được hỗ trợ'),
          leading: AppCloseButton(
            fallbackRoute: '/beneficiaries',
            onPressed: requestExit,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Lưu',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar edit section
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 2.5),
                        image: _avatarPath != null && _avatarPath!.isNotEmpty
                            ? DecorationImage(
                                image: beneficiaryAvatarImageProvider(
                                    _avatarPath!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _avatarPath != null && _avatarPath!.isNotEmpty
                          ? null
                          : const Center(
                              child: Icon(Icons.person_add_outlined,
                                  size: 40, color: AppColors.primary),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── THÔNG TIN CƠ BẢN ─────────────────────────────────
              _buildSectionHeader('👤 Thông tin cơ bản'),

              _buildLabel('Họ và tên *'),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(hintText: 'Nhập họ tên đầy đủ'),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 16),

              // Tuổi + Giới tính
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Tuổi *'),
                        TextFormField(
                          controller: _ageCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: const InputDecoration(hintText: 'VD: 75'),
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return 'Nhập tuổi';
                            final age = int.tryParse(v!.trim());
                            if (age == null || age < 0 || age > 120) {
                              return 'Tuổi không hợp lệ';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Giới tính'),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: const InputDecoration(),
                          items: _genders
                              .map((g) =>
                                  DropdownMenuItem(value: g, child: Text(g)))
                              .toList(),
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildLabel('Quan hệ với bạn'),
              _buildDropdown(
                  _relations, _relation, (v) => setState(() => _relation = v!)),
              const SizedBox(height: 16),

              _buildLabel('Địa chỉ chăm sóc *'),
              VerifiedBeneficiaryAddressPicker(
                selectedAddressId: _selectedAddress?.id,
                onChanged: (address) =>
                    setState(() => _selectedAddress = address),
              ),
              const SizedBox(height: 16),

              _buildLabel('Mức độ chăm sóc'),
              Row(
                children: _careLevels.map((level) {
                  final isSelected = level == _careLevel;
                  final color = level == 'Nặng'
                      ? AppColors.error
                      : level == 'Trung bình'
                          ? AppColors.warning
                          : AppColors.success;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _careLevel = level),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.13)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? color : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          level,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? color : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // ── THÔNG TIN CẦN BIẾT ─────────────────────────────────────
              _buildSectionHeader('📋 Thông tin cần biết'),

              _buildTagInput(
                label: 'Nhu cầu hỗ trợ / Lưu ý',
                hint:
                    'VD: Hay quên, khó di chuyển, cần đồng hành... nhấn + để thêm',
                ctrl: _conditionCtrl,
                tags: _conditions,
                tagColor: AppColors.info,
              ),
              const SizedBox(height: 16),

              _buildLabel('Ghi chú đặc biệt cho người chăm sóc'),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText:
                      'Sở thích, thói quen, lưu ý an toàn, chế độ ăn đặc biệt...',
                ),
              ),
              const SizedBox(height: 28),

              // ── LIÊN HỆ KHẨN CẤP (FR-CUS-04) ────────────────────
              _buildSectionHeader('🚨 Liên hệ khẩn cấp'),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bắt buộc ít nhất 2 liên hệ khẩn cấp. Những người này sẽ được thông báo ngay khi xảy ra sự cố trong ca chăm sóc.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              ..._contacts
                  .asMap()
                  .entries
                  .map((e) => _buildContactCard(e.key, e.value)),

              TextButton.icon(
                onPressed: () => setState(() => _contacts.add(_ECEntry())),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Thêm liên hệ khẩn cấp'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Thêm người được chăm sóc',
                        style: TextStyle(fontSize: 15)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets phụ ──────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: ctrl,
                decoration: InputDecoration(hintText: hint),
                onFieldSubmitted: (_) => _addTag(ctrl, tags),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addTag(ctrl, tags),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.add, color: AppColors.primary, size: 22),
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: tags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => tags.remove(tag)),
                    backgroundColor: tagColor.withValues(alpha: 0.1),
                    side: BorderSide(color: tagColor.withValues(alpha: 0.3)),
                    labelStyle: TextStyle(
                      color: tagColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildContactCard(int index, _ECEntry entry) {
    final canRemove = _contacts.length > 2;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Liên hệ khẩn cấp ${index + 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _selectFamilyContact(entry),
                icon: const Icon(Icons.people_outline, size: 17),
                label: const Text('Danh bạ'),
              ),
              if (canRemove)
                GestureDetector(
                  onTap: () => setState(() => _contacts.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Tên
          TextFormField(
            controller: entry.nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Họ tên *',
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
            validator: (v) => (v?.trim().isEmpty ?? true)
                ? 'Vui lòng nhập tên liên hệ'
                : null,
          ),
          const SizedBox(height: 10),

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
            validator: (v) {
              if (v?.trim().isEmpty ?? true) {
                return 'Vui lòng nhập số điện thoại';
              }
              if (!RegExp(r'^0[3-9]\d{8}$').hasMatch(v!.trim())) {
                return 'Số điện thoại không hợp lệ';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _saveToFamilyContacts(entry),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
              label: const Text('Lưu vào danh bạ gia đình'),
            ),
          ),
          const SizedBox(height: 2),

          // Mối quan hệ
          DropdownButtonFormField<String>(
            initialValue: entry.relationship,
            decoration: const InputDecoration(
              labelText: 'Mối quan hệ',
              prefixIcon: Icon(Icons.family_restroom_outlined, size: 18),
            ),
            items: _contactRelations
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => entry.relationship = v!),
          ),
        ],
      ),
    );
  }
}
