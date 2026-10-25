import 'package:caresitter_customer/features/auth/presentation/widgets/phone_login_form.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/phone_login_security_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/auth_session_controller.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập số điện thoại';
    final cleaned = value.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^(0[3-9]\d{8}|84[3-9]\d{8})$').hasMatch(cleaned)) {
      return 'Số điện thoại không hợp lệ';
    }
    return null;
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final phone = _phoneController.text.trim();
      await ref.read(authSessionControllerProvider).requestOtp(phone);
      if (mounted) context.push(AppRoutes.otp, extra: phone);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Hero Header ──────────────────────
              const PhoneLoginSecurityIcon(),

              // ── Form ────────────────────────────
              PhoneLoginForm(
                  isCompact: isCompact,
                  formKey: _formKey,
                  phoneController: _phoneController,
                  validatePhone: _validatePhone,
                  requestOtp: _requestOtp,
                  isLoading: _isLoading),
            ],
          ),
        ),
      ),
    );
  }
}
