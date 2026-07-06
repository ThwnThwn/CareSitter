import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late TextEditingController _expController;
  late TextEditingController _locationController;
  late TextEditingController _rateController;
  late TextEditingController _certController;
  late List<String> _skills;

  final _skillInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile.name);
    _expController = TextEditingController(text: profile.experience);
    _locationController = TextEditingController(text: profile.location);
    _rateController = TextEditingController(text: profile.hourlyRate.toInt().toString());
    _certController = TextEditingController(text: profile.certifications);
    _skills = List.from(profile.skills);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _expController.dispose();
    _locationController.dispose();
    _rateController.dispose();
    _certController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(profileProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          experience: _expController.text.trim(),
          location: _locationController.text.trim(),
          hourlyRate: double.tryParse(_rateController.text.trim()) ?? 0,
          skills: _skills,
          certifications: _certController.text.trim(),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật thông tin cá nhân thành công'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text(
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
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        _nameController.text.isNotEmpty
                            ? _nameController.text.split(' ').last.substring(0, 1).toUpperCase()
                            : 'CG',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
              const SizedBox(height: 32),

              // ── Fields ──
              _buildSectionTitle('Thông tin cơ bản'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                label: 'Họ và tên',
                hint: 'Nhập họ và tên đầy đủ',
                icon: Icons.person_outline,
                validator: (val) => val == null || val.isEmpty ? 'Họ tên không được trống' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _locationController,
                label: 'Khu vực hoạt động',
                hint: 'Ví dụ: Quận 5, TP.HCM',
                icon: Icons.location_on_outlined,
                validator: (val) => val == null || val.isEmpty ? 'Khu vực không được trống' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _expController,
                label: 'Kinh nghiệm',
                hint: 'Ví dụ: 3 năm kinh nghiệm',
                icon: Icons.workspace_premium_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _rateController,
                label: 'Mức lương mong muốn (đ/giờ)',
                hint: 'Ví dụ: 80000',
                icon: Icons.monetization_on_outlined,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Vui lòng nhập giá';
                  if (double.tryParse(val) == null) return 'Mức lương không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Kỹ năng chuyên môn'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _skillInputController,
                      label: 'Thêm kỹ năng',
                      hint: 'Ví dụ: Chăm trẻ sơ sinh',
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
                    deleteIcon: const Icon(Icons.cancel, size: 16, color: AppColors.primary),
                    onDeleted: () => _removeSkill(skill),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.transparent),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Bằng cấp & Chứng chỉ'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _certController,
                label: 'Chứng chỉ',
                hint: 'Nhập các bằng cấp, chứng chỉ cách nhau bởi dấu phẩy',
                icon: Icons.description_outlined,
                maxLines: 3,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
