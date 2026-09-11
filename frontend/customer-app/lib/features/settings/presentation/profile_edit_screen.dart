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
  late TextEditingController _displayNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _dobCtrl;
  String _gender = 'UNSPECIFIED';
  bool _isSaving = false;
  File? _pendingAvatarFile; // ảnh mới chưa upload
  late final String _initialFormState;

  String get _formState => [
        _nameCtrl.text,
        _displayNameCtrl.text,
        _emailCtrl.text,
        _dobCtrl.text,
        _gender,
        _pendingAvatarFile?.path ?? '',
      ].toString();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileStoreProvider);
    _nameCtrl = TextEditingController(text: profile.name);
    _displayNameCtrl = TextEditingController(text: profile.displayName);
    _emailCtrl = TextEditingController(text: profile.email);

    // DOB từ server: yyyy-MM-dd → hiển thị dd/MM/yyyy
    final dob = profile.dob;
    _dobCtrl = TextEditingController(text: _serverDobToDisplay(dob));

    // Gender từ enum → display
    _gender = profile.gender.isNotEmpty ? profile.gender : 'UNSPECIFIED';
    _initialFormState = _formState;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  /// yyyy-MM-dd → dd/MM/yyyy
  String _serverDobToDisplay(String? dob) {
    if (dob == null || dob.isEmpty) return '';
    final parts = dob.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    return dob;
  }

  Future<void> _selectDate() async {
    DateTime initialDate;
    try {
      final parts = _dobCtrl.text.split('/');
      if (parts.length == 3) {
        initialDate = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      } else {
        initialDate = DateTime(1990, 1, 1);
      }
    } catch (_) {
      initialDate = DateTime(1990, 1, 1);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
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

  Future<void> _pickAvatar() async {
    if (ref.read(avatarUploadingProvider)) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _pendingAvatarFile = File(image.path));
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
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Bước 1: Upload avatar trước (nếu có ảnh mới)
      if (_pendingAvatarFile != null) {
        final uploaded = await ref
            .read(profileStoreProvider.notifier)
            .uploadAvatar(_pendingAvatarFile!);
        if (!uploaded && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Upload ảnh thất bại. Thông tin khác vẫn được lưu.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        setState(() => _pendingAvatarFile = null);
      }

      // Bước 2: Cập nhật thông tin profile — chỉ update sau khi API thành công
      final success = await ref.read(profileStoreProvider.notifier).updateProfile(
            name: _nameCtrl.text.trim(),
            displayName: _displayNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            dob: _dobCtrl.text.trim(),
            gender: _gender,
          );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã cập nhật thông tin cá nhân!'),
            backgroundColor: AppColors.primary,
          ),
        );
        popOrGo(context, fallbackRoute: '/settings');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Cập nhật thất bại. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
        // Không pop — để user thử lại. State vẫn là giá trị cũ từ server.
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileStoreProvider);
    final isUploadingAvatar = ref.watch(avatarUploadingProvider);

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
              onPressed: (_isSaving || isUploadingAvatar) ? null : _saveProfile,
              child: const Text(
                'Lưu',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
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
              // ── Avatar ───────────────────────────────────────────────────
              Center(
                child: Stack(
                  children: [
                    _AvatarWidget(
                      avatarUrl: _pendingAvatarFile != null
                          ? null // preview local file bên dưới
                          : profile.avatarUrl,
                      localFile: _pendingAvatarFile,
                      initials: _buildInitials(_nameCtrl.text),
                      isUploading: isUploadingAvatar,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: (isUploadingAvatar || _isSaving)
                            ? null
                            : _pickAvatar,
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

              // ── Tài khoản & Liên hệ ──────────────────────────────────────
              _buildSectionHeader('Tài khoản & Liên hệ'),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                onChanged: (_) => setState(() {}), // cập nhật initials realtime
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Vui lòng nhập họ tên hợp lệ (ít nhất 2 ký tự)'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  helperText: 'Để trống → dùng họ tên',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Số điện thoại — readonly (identity/login)
              TextFormField(
                initialValue: profile.phone,
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

              // ── Thông tin cá nhân ─────────────────────────────────────────
              _buildSectionHeader('Thông tin cá nhân'),
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
                        DropdownMenuItem(value: 'MALE', child: Text('Nam')),
                        DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                        DropdownMenuItem(
                            value: 'UNSPECIFIED', child: Text('Không rõ')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _gender = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: (_isSaving || isUploadingAvatar) ? null : _saveProfile,
                child: (_isSaving || isUploadingAvatar)
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

  String _buildInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.map((p) => p[0].toUpperCase()).take(3).join();
    return initials.isNotEmpty ? initials : 'U';
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
    );
  }
}

// ── Avatar Widget ────────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final File? localFile;
  final String initials;
  final bool isUploading;

  const _AvatarWidget({
    this.avatarUrl,
    this.localFile,
    required this.initials,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (localFile != null) {
      image = kIsWeb
          ? NetworkImage(localFile!.path) as ImageProvider
          : FileImage(localFile!);
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      image = NetworkImage(avatarUrl!);
    }

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: image == null ? AppColors.primaryGradient : null,
        shape: BoxShape.circle,
        boxShadow: AppShadows.elevated,
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
        color: image != null ? AppColors.surfaceVariant : null,
      ),
      child: isUploading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
          : image == null
              ? Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
    );
  }
}
