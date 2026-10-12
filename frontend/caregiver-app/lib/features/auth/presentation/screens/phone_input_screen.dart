import 'package:caregiver_app/features/auth/presentation/widgets/login_form.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/login_controller.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key, this.startWithOtp = false});
  final bool startWithOtp;

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _usePassword = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usePassword = !widget.startWithOtp;
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _usePassword
          ? 'Vui lòng nhập email hoặc số điện thoại'
          : 'Vui lòng nhập email';
    }
    if (!_usePassword &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (!_usePassword) return null;
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < 6) {
      return 'Mật khẩu tối thiểu 6 ký tự';
    }
    return null;
  }

  Future<void> _loginWithPassword() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text;
      await ref
          .read(loginControllerProvider)
          .loginWithPassword(identifier, password);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestOtp() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final email = _identifierController.text.trim().toLowerCase();
      await ref.read(loginControllerProvider).requestOtp(email);
      if (mounted) context.push('/auth/otp', extra: email);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Hero Header ──────────────────────
              const LoginHero(),

              // ── Form ────────────────────────────
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: LoginForm(
                      usePassword: _usePassword,
                      identifierController: _identifierController,
                      validateIdentifier: _validateIdentifier,
                      passwordController: _passwordController,
                      obscurePassword: _obscurePassword,
                      validatePassword: _validatePassword,
                      isLoading: _isLoading,
                      loginWithPassword: _loginWithPassword,
                      requestOtp: _requestOtp,
                      callbackAction3: () =>
                          setState(() => _usePassword = true),
                      callbackAction4: () =>
                          setState(() => _usePassword = false),
                      callbackAction5: () =>
                          setState(() => _obscurePassword = !_obscurePassword)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
