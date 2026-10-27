import 'package:caregiver_app/features/auth/presentation/widgets/login_form.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
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
        AppToast.error(
          context,
          e.toString().replaceAll('Exception: ', ''),
          title: 'Đăng nhập chưa thành công',
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
        AppToast.error(
          context,
          e.toString(),
          title: 'Chưa thể gửi OTP',
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
                      passwordController: _passwordController,
                      obscurePassword: _obscurePassword,
                      isLoading: _isLoading,
                      loginWithPassword: _loginWithPassword,
                      requestOtp: _requestOtp,
                      onMethodChanged: (value) =>
                          setState(() => _usePassword = value),
                      onTogglePassword: () =>
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
