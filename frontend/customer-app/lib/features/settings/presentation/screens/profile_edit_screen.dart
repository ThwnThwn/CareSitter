import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_form.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_app_bar.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import '../controllers/profile_edit_controller.dart';
import '../widgets/profile_avatar_picker.dart';

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
  XFile? _pendingAvatarFile; // ảnh mới chưa upload
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
    if (picked != null && mounted) {
      setState(() {
        _dobCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _pickAvatar() async {
    if (ref.read(avatarUploadingProvider) ||
        ref.read(profileEditControllerProvider).busy) {
      return;
    }
    try {
      final image = await ProfileAvatarPicker.pick(isActive: () => mounted);
      if (mounted &&
          image != null &&
          !ref.read(profileEditControllerProvider).busy) {
        setState(() => _pendingAvatarFile = image);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Không chọn được ảnh. Vui lòng thử lại.')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref.read(profileEditControllerProvider.notifier).save(
        name: _nameCtrl.text,
        displayName: _displayNameCtrl.text,
        email: _emailCtrl.text,
        dob: _dobCtrl.text,
        gender: _gender,
        avatar: _pendingAvatarFile);
    if (!mounted || result.ignored) return;
    if (result.avatarUploaded) setState(() => _pendingAvatarFile = null);
    if (result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message!),
          backgroundColor: result.saved ? AppColors.warning : AppColors.error));
      return;
    }
    if (result.saved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Đã cập nhật thông tin cá nhân!'),
          backgroundColor: AppColors.primary));
      popOrGo(context, fallbackRoute: '/settings');
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
        appBar: ProfileEditAppBar(
            requestExit: requestExit,
            ref: ref,
            isUploadingAvatar: isUploadingAvatar,
            saveProfile: _saveProfile),
        body: ProfileEditForm(
            formKey: _formKey,
            pendingAvatarFile: _pendingAvatarFile,
            profile: profile,
            buildInitials: _buildInitials,
            nameCtrl: _nameCtrl,
            isUploadingAvatar: isUploadingAvatar,
            ref: ref,
            pickAvatar: _pickAvatar,
            buildSectionHeader: _buildSectionHeader,
            displayNameCtrl: _displayNameCtrl,
            emailCtrl: _emailCtrl,
            dobCtrl: _dobCtrl,
            selectDate: _selectDate,
            gender: _gender,
            saveProfile: _saveProfile,
            callbackAction1: (_) => setState(() {}),
            callbackAction2: (v) => (v == null || v.trim().length < 2)
                ? 'Vui lòng nhập họ tên hợp lệ (ít nhất 2 ký tự)'
                : null,
            callbackAction3: () => context.push('/settings/recovery-email'),
            callbackAction4: (v) {
              if (v != null && v.isNotEmpty && !v.contains('@')) {
                return 'Email không hợp lệ';
              }
              return null;
            },
            callbackAction5: (v) {
              if (v != null) setState(() => _gender = v);
            }),
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
          fontSize: AppFontSizes.s14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary),
    );
  }
}

// ── Avatar Widget ────────────────────────────────────────────────────────────
