import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/profile_store.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _addressCtrl;
  String _gender = 'Nam';
  String _language = 'Tiếng Việt';
  String? _avatarPath;
  bool _isSaving = false;
  late final String _initialFormState;

  String get _formState => [
        _nameCtrl.text,
        _emailCtrl.text,
        _dobCtrl.text,
        _addressCtrl.text,
        _gender,
        _language,
        _avatarPath ?? '',
      ].toString();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileStoreProvider);
    _nameCtrl = TextEditingController(text: profile.name);
    _emailCtrl = TextEditingController(text: profile.email);
    _dobCtrl = TextEditingController(text: profile.dob);
    _addressCtrl = TextEditingController(text: profile.address);
    _gender = profile.gender;
    _language = profile.language;
    _avatarPath = profile.avatarPath;
    _initialFormState = _formState;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1985, 8, 15),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final success = await ref.read(profileStoreProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          dob: _dobCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          gender: _gender,
          language: _language,
          avatarPath: _avatarPath,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Đã cập nhật thông tin cá nhân thành công!'
                : '⚠️ Cập nhật thành công (lưu local). Đồng bộ server khi có mạng.',
          ),
          backgroundColor: success ? AppColors.primary : Colors.orange,
        ),
      );
      popOrGo(context, fallbackRoute: '/settings');
    }
  }


  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _formState != _initialFormState,
      fallbackRoute: '/settings',
      builder: (context, requestExit) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Thông tin cá nhân'),
          leading: AppBackButton(
            fallbackRoute: '/settings',
            onPressed: requestExit,
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: const Text('Lưu',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar section
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.elevated,
                        image: _avatarPath != null && _avatarPath!.isNotEmpty
                            ? DecorationImage(
                                image: kIsWeb
                                    ? NetworkImage(_avatarPath!) as ImageProvider
                                    : FileImage(File(_avatarPath!)) as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _avatarPath != null && _avatarPath!.isNotEmpty
                          ? null
                          : Center(
                              child: Text(
                                () {
                                  final initials = _nameCtrl.text.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((p) => p[0].toUpperCase()).take(3).join();
                                  return initials.isNotEmpty ? initials : 'U';
                                }(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Basic info
              _buildSectionHeader('Tài khoản & Liên hệ'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Vui lòng nhập họ tên hợp lệ'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: ref.read(profileStoreProvider).phone,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại (Cố định)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  suffixIcon: Icon(Icons.lock_outline, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty && !v.contains('@')) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Section 2: Personal details
              _buildSectionHeader('Thông tin cá nhân bổ sung'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dobCtrl,
                      readOnly: true,
                      onTap: _selectDate,
                      decoration: const InputDecoration(
                        labelText: 'Ngày sinh',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Giới tính',
                        prefixIcon: Icon(Icons.people_outline),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                        DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                        DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _gender = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ mặc định',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(
                  labelText: 'Ngôn ngữ ứng dụng',
                  prefixIcon: Icon(Icons.language_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'Tiếng Việt', child: Text('Tiếng Việt')),
                  DropdownMenuItem(value: 'English', child: Text('English')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _language = v);
                },
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Lưu thay đổi'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
    );
  }
}
