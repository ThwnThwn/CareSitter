import 'package:caresitter_customer/features/auth/presentation/widgets/otp_verification_content.dart';
import '../controllers/otp_controller.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _resendOtp() async {
    final sent =
        await ref.read(otpControllerProvider(widget.email).notifier).resend();
    if (mounted && sent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mã OTP mới đã được gửi đến email của bạn.'),
          backgroundColor: AppColors.primary));
    }
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
    final success = await ref
        .read(otpControllerProvider(widget.email).notifier)
        .submit(_otp);
    if (!mounted ||
        success ||
        ref.read(otpControllerProvider(widget.email)).error == null) {
      return;
    }
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(
          fallbackRoute: '/auth/email',
          color: AppColors.textPrimary,
        ),
      ),
      body: OtpVerificationContent(
          ref: ref,
          buildOtpBox: _buildOtpBox,
          otp: _otp,
          verify: _verify,
          resendOtp: _resendOtp,
          routeEmail: widget.email),
    );
  }

  Widget _buildOtpBox(int index) {
    final isFocused = _focusNodes[index].hasFocus;
    final hasValue = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 46,
      height: 54,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: AppFontSizes.s20,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor:
              isFocused ? AppColors.primaryContainer : AppColors.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: hasValue ? AppColors.primary : AppColors.border,
              width: isFocused ? 2 : 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: hasValue ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: AppSpacing.compact),
        ),
        onChanged: (value) => _onDigitChanged(index, value),
      ),
    );
  }
}
