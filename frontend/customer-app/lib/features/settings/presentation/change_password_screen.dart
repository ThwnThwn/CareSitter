import 'package:flutter/material.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  bool get _hasUnsavedChanges =>
      _oldPassCtrl.text.isNotEmpty ||
      _newPassCtrl.text.isNotEmpty ||
      _confirmPassCtrl.text.isNotEmpty;

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tính năng đổi mật khẩu chưa được backend hỗ trợ.'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DiscardChangesGuard(
      hasChanges: () => _hasUnsavedChanges,
      fallbackRoute: '/settings',
      builder: (context, requestExit) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Đổi mật khẩu'),
          leading: AppBackButton(
            fallbackRoute: '/settings',
            onPressed: requestExit,
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.warning, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mật khẩu mới phải có ít nhất 8 ký tự, bao gồm chữ cái và số.',
                        style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildLabel('Mật khẩu hiện tại'),
              _buildPasswordField(
                controller: _oldPassCtrl,
                hint: 'Nhập mật khẩu hiện tại',
                obscure: _obscureOld,
                onToggle: () => setState(() => _obscureOld = !_obscureOld),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Vui lòng nhập mật khẩu cũ'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Mật khẩu mới'),
              _buildPasswordField(
                controller: _newPassCtrl,
                hint: 'Nhập mật khẩu mới',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Vui lòng nhập mật khẩu mới';
                  }
                  if (v.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Xác nhận mật khẩu mới'),
              _buildPasswordField(
                controller: _confirmPassCtrl,
                hint: 'Nhập lại mật khẩu mới',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu';
                  }
                  if (v != _newPassCtrl.text) {
                    return 'Mật khẩu xác nhận không khớp';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Cập nhật mật khẩu',
                        style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20),
          onPressed: onToggle,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
