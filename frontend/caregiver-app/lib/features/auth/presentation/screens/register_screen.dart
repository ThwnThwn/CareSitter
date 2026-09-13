import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/dio_client.dart';
import '../../../../core/router/navigation_helpers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _agreed = false;
  bool _submitting = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error = 'Vui lòng đồng ý với điều khoản sử dụng.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).register(
            fullName: _nameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            password: _passwordController.text,
            confirmPassword: _confirmController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đăng ký thành công. Bạn có thể đăng nhập ngay.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      context.go('/auth/phone');
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _requiredName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) return 'Vui lòng nhập đầy đủ họ tên';
    return null;
  }

  String? _validEmail(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^[\w.+-]+@[\w-]+(?:\.[\w-]+)+$').hasMatch(text)) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  String? _validPhone(String? value) {
    if (!RegExp(r'^0[3-9]\d{8}$').hasMatch(value?.trim() ?? '')) {
      return 'Số điện thoại Việt Nam gồm 10 chữ số';
    }
    return null;
  }

  String? _validPassword(String? value) {
    final text = value ?? '';
    if (text.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự';
    if (!RegExp(r'[A-Z]').hasMatch(text)) return 'Cần ít nhất một chữ hoa';
    if (!RegExp(r'\d').hasMatch(text)) return 'Cần ít nhất một chữ số';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đăng ký Caregiver'),
        leading: const AppBackButton(fallbackRoute: '/auth/phone'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              const Icon(Icons.medical_services_rounded,
                  color: AppColors.primary, size: 44),
              const SizedBox(height: 12),
              const Text(
                'Tham gia đội ngũ chăm sóc',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tạo tài khoản trước, sau đó hoàn thiện hồ sơ và giấy tờ KYC.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: _requiredName,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _validEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: _validPhone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _passwordField(
                controller: _passwordController,
                label: 'Mật khẩu',
                hidden: _hidePassword,
                validator: _validPassword,
                onToggle: () => setState(() => _hidePassword = !_hidePassword),
              ),
              const SizedBox(height: 16),
              _passwordField(
                controller: _confirmController,
                label: 'Xác nhận mật khẩu',
                hidden: _hideConfirmation,
                validator: (value) => value != _passwordController.text
                    ? 'Mật khẩu xác nhận không khớp'
                    : null,
                onToggle: () =>
                    setState(() => _hideConfirmation = !_hideConfirmation),
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _agreed,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _agreed = value ?? false),
                title: const Text(
                  'Tôi đồng ý với điều khoản sử dụng và chính sách bảo mật.',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: 'Tạo tài khoản Caregiver',
                icon: Icons.person_add_alt_1_rounded,
                isLoading: _submitting,
                onPressed: _submitting ? null : _register,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _submitting ? null : () => context.go('/auth/phone'),
                child: const Text('Đã có tài khoản? Đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required String? Function(String?) validator,
    required VoidCallback onToggle,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: hidden,
      textInputAction:
          onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      validator: validator,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: onToggle,
          icon: Icon(hidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
        ),
      ),
    );
  }
}
