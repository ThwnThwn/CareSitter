import 'package:caresitter_customer/features/auth/presentation/widgets/email_login_form.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/email_login_security_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/auth_session_controller.dart';

class EmailInputScreen extends ConsumerStatefulWidget {
  const EmailInputScreen({super.key});

  @override
  ConsumerState<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends ConsumerState<EmailInputScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Email không đúng định dạng';
    }
    return null;
  }

  Future<void> _requestOtp() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    try {
      await ref.read(authSessionControllerProvider).sendOtp(email);
      if (mounted) {
        context.push('/auth/otp', extra: email);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final msg = e.toString();
          if (msg.contains('404')) {
            _errorMessage = 'Email chưa được đăng ký trong hệ thống.';
          } else if (msg.contains('connect') || msg.contains('internet')) {
            _errorMessage = 'Không thể kết nối máy chủ. Vui lòng thử lại.';
          } else {
            _errorMessage = 'Gửi mã OTP thất bại. Vui lòng kiểm tra lại email.';
          }
        });
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
              const EmailLoginSecurityIcon(),

              // ── Form ────────────────────────────
              EmailLoginForm(
                  isCompact: isCompact,
                  formKey: _formKey,
                  errorMessage: _errorMessage,
                  emailController: _emailController,
                  validateEmail: _validateEmail,
                  requestOtp: _requestOtp,
                  isLoading: _isLoading),
            ],
          ),
        ),
      ),
    );
  }
}
