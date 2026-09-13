import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../profile/presentation/providers/profile_provider.dart';

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
  late TextEditingController _rateController;
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
    _rateController = TextEditingController(
      text: profile.hourlyRateExpected != null
          ? profile.hourlyRateExpected.toString()
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
    _rateController.dispose();
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
      if (picked == null) return;

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

    if (picked != null) {
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
          hourlyRateExpected: int.tryParse(_rateController.text.trim()),
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
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile Photo Editor ──
              Center(
                child: GestureDetector(
                  onTap: isUploadingAvatar ? null : _pickAndUploadAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: AppColors.primaryContainer,
                        backgroundImage: profile.avatarUrl != null &&
                                profile.avatarUrl!.isNotEmpty
                            ? ResizeImage(
                                CachedNetworkImageProvider(profile.avatarUrl!),
                                width: 192)
                            : null,
                        child: isUploadingAvatar
                            ? const CircularProgressIndicator(
                                color: AppColors.primary)
                            : (profile.avatarUrl == null ||
                                    profile.avatarUrl!.isEmpty)
                                ? Text(
                                    profile.initials,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Chạm để đổi ảnh đại diện',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 28),

              // ── Basic Info ──
              _buildSectionTitle('Thông tin cơ bản'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                label: 'Họ và tên',
                hint: 'Nhập họ và tên đầy đủ',
                icon: Icons.person_outline,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Họ tên không được trống'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _bioController,
                label: 'Giới thiệu bản thân',
                hint: 'Tóm tắt kinh nghiệm và phong cách làm việc của bạn',
                icon: Icons.article_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ── Gender & DOB ──
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: ['MALE', 'FEMALE', 'OTHER', 'UNSPECIFIED']
                              .contains(_gender)
                          ? _gender
                          : 'UNSPECIFIED',
                      decoration: InputDecoration(
                        labelText: 'Giới tính',
                        prefixIcon: const Icon(Icons.transgender,
                            color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MALE', child: Text('Nam')),
                        DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                        DropdownMenuItem(
                            value: 'UNSPECIFIED', child: Text('Chưa rõ')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _gender = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDateOfBirth,
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: _dobController,
                          label: 'Ngày sinh',
                          hint: 'YYYY-MM-DD',
                          icon: Icons.calendar_today_outlined,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Location & Experience ──
              _buildSectionTitle('Khu vực & Kinh nghiệm'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _districtController,
                      label: 'Quận/Huyện',
                      hint: 'Ví dụ: Quận 5',
                      icon: Icons.location_city_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _cityController,
                      label: 'Tỉnh/Thành phố',
                      hint: 'Ví dụ: TP.HCM',
                      icon: Icons.map_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _expController,
                label: 'Số năm kinh nghiệm',
                hint: 'Ví dụ: 3',
                icon: Icons.workspace_premium_outlined,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val != null &&
                      val.isNotEmpty &&
                      int.tryParse(val) == null) {
                    return 'Vui lòng nhập số nguyên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _rateController,
                label: 'Mức giá mong muốn (đ/giờ)',
                hint: 'Ví dụ: 80000',
                icon: Icons.monetization_on_outlined,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val != null &&
                      val.isNotEmpty &&
                      int.tryParse(val) == null) {
                    return 'Vui lòng nhập số nguyên hợp lệ';
                  }
                  return null;
                },
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '💡 Mức giá mong muốn chỉ là thông tin tham khảo trên hồ sơ, không thay đổi biểu phí dịch vụ tiêu chuẩn của ứng dụng.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3),
                ),
              ),
              const SizedBox(height: 24),

              // ── Skills ──
              _buildSectionTitle('Kỹ năng chuyên môn'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _skillInputController,
                      label: 'Thêm kỹ năng',
                      hint: 'Ví dụ: Chăm sóc người cao tuổi, tiêm insulin...',
                      icon: Icons.star_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: _addSkill,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills.map((skill) {
                  return Chip(
                    backgroundColor: AppColors.primaryContainer,
                    label: Text(
                      skill,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.cancel,
                        size: 16, color: AppColors.primary),
                    onDeleted: () => _removeSkill(skill),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.transparent),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
