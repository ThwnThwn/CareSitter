import 'package:caregiver_app/features/auth/presentation/widgets/otp_resend_action.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/otp_confirm_action.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/otp_email_notice.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/otp_security_icon.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/otp_digit_field.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/otp_verify_controller.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpVerifyScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _countdown = 60;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
    if (_otp.length == 6) _verify();
  }

  Future<void> _verify() async {
    if (_isVerifying || _isResending || _otp.length != 6) return;
    setState(() => _isVerifying = true);
    try {
      await ref.read(otpVerifyControllerProvider).verify(widget.email, _otp);
      if (mounted) {
        setState(() => _isVerifying = false);
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xác thực OTP thất bại: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isVerifying || _isResending || _countdown > 0) return;
    setState(() => _isResending = true);
    try {
      await ref.read(otpVerifyControllerProvider).resend(widget.email);
      if (mounted) _startCountdown();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể gửi lại OTP: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(
          fallbackRoute: '/auth/phone',
          color: AppColors.textPrimary,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              const OtpSecurityIcon(),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Xác minh OTP',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.s26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OtpEmailNotice(routeEmail: widget.email),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),
              const SizedBox(height: 40),
              OtpConfirmAction(
                  otp: _otp, isVerifying: _isVerifying, verify: _verify),
              const SizedBox(height: AppSpacing.lg),
              OtpResendAction(
                  countdown: _countdown,
                  isResending: _isResending,
                  resendOtp: _resendOtp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) => OtpDigitField(
      focusNodes: _focusNodes,
      index: index,
      controllers: _controllers,
      onDigitChanged: _onDigitChanged);
}
