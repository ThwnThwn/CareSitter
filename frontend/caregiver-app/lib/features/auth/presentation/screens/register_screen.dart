import 'package:caregiver_app/features/auth/presentation/widgets/registration_content.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/registration_password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caregiver_app/core/error/failure.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/register_controller.dart';

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
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error = 'Vui lòng đồng ý với điều khoản sử dụng.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(registerControllerProvider).register(
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
    return RegistrationContent(
        formKey: _formKey,
        nameController: _nameController,
        requiredName: _requiredName,
        emailController: _emailController,
        validEmail: _validEmail,
        phoneController: _phoneController,
        validPhone: _validPhone,
        passwordField: _passwordField,
        passwordController: _passwordController,
        hidePassword: _hidePassword,
        validPassword: _validPassword,
        confirmController: _confirmController,
        hideConfirmation: _hideConfirmation,
        agreed: _agreed,
        submitting: _submitting,
        error: _error,
        register: _register,
        callbackAction2: () => setState(() => _hidePassword = !_hidePassword),
        callbackAction3: (value) => value != _passwordController.text
            ? 'Mật khẩu xác nhận không khớp'
            : null,
        callbackAction7: () =>
            setState(() => _hideConfirmation = !_hideConfirmation),
        callbackAction8: (_) => _register(),
        callbackAction9: (value) => setState(() => _agreed = value ?? false));
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required String? Function(String?) validator,
    required VoidCallback onToggle,
    ValueChanged<String>? onSubmitted,
  }) =>
      RegistrationPasswordField(
          controller: controller,
          hidden: hidden,
          onSubmitted: onSubmitted,
          validator: validator,
          label: label,
          onToggle: onToggle);
}
