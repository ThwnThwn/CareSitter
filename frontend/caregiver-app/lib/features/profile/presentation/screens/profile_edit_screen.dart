import 'package:caregiver_app/features/profile/presentation/widgets/profile_edit_form.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_edit_app_bar.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _expController;
  late TextEditingController _cityController;
  late TextEditingController _districtController;
  late TextEditingController _dobController;
  late List<String> _skills;
  String _gender = 'UNSPECIFIED';
  bool _isSaving = false;

  final _skillInputController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile.fullName ?? '');
    _bioController = TextEditingController(text: profile.bio ?? '');
    _expController = TextEditingController(
      text: profile.yearsOfExperience != null
          ? profile.yearsOfExperience.toString()
          : '',
    );
    _cityController = TextEditingController(text: profile.serviceCity ?? '');
    _districtController =
        TextEditingController(text: profile.serviceDistrict ?? '');
    _dobController = TextEditingController(text: profile.dateOfBirth ?? '');
    _skills = List.from(profile.skills);
    _gender = profile.gender ?? 'UNSPECIFIED';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _expController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _dobController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final isUploading = ref.read(caregiverAvatarUploadingProvider);
    if (isUploading) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final success = await ref
          .read(profileProvider.notifier)
          .uploadAvatar(File(picked.path));

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật ảnh đại diện thành công'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tải ảnh thất bại. Vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _selectDateOfBirth() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 25));
    if (_dobController.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_dobController.text);
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );

    if (picked != null && mounted) {
      final yyyy = picked.year.toString().padLeft(4, '0');
      final mm = picked.month.toString().padLeft(2, '0');
      final dd = picked.day.toString().padLeft(2, '0');
      setState(() {
        _dobController.text = '$yyyy-$mm-$dd';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    final success = await ref.read(profileProvider.notifier).updateProfile(
          fullName: _nameController.text.trim(),
          bio: _bioController.text.trim(),
          yearsOfExperience: int.tryParse(_expController.text.trim()),
          skills: _skills,
          serviceCity: _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
              : null,
          serviceDistrict: _districtController.text.trim().isNotEmpty
              ? _districtController.text.trim()
              : null,
          gender: _gender,
          dateOfBirth: _dobController.text.trim().isNotEmpty
              ? _dobController.text.trim()
              : null,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật thông tin cá nhân thành công'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thất bại. Vui lòng kiểm tra lại kết nối.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addSkill() {
    final text = _skillInputController.text.trim();
    if (text.isNotEmpty && !_skills.contains(text)) {
      setState(() {
        _skills.add(text);
        _skillInputController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final isUploadingAvatar = ref.watch(caregiverAvatarUploadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ProfileEditAppBar(isSaving: _isSaving, saveProfile: _saveProfile),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ProfileEditForm(
            formKey: _formKey,
            profile: profile,
            isUploadingAvatar: isUploadingAvatar,
            pickAndUploadAvatar: _pickAndUploadAvatar,
            nameController: _nameController,
            bioController: _bioController,
            gender: _gender,
            dobController: _dobController,
            selectDateOfBirth: _selectDateOfBirth,
            districtController: _districtController,
            cityController: _cityController,
            expController: _expController,
            skills: _skills,
            skillInputController: _skillInputController,
            addSkill: _addSkill,
            removeSkill: _removeSkill,
            onGenderChanged: (v) => setState(() => _gender = v)),
      ),
    );
  }
}
