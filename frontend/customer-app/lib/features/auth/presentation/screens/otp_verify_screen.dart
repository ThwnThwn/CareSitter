import 'package:caresitter_customer/features/auth/presentation/widgets/otp_verification_content.dart';
import '../controllers/otp_controller.dart';
import 'dart:async';
import 'package:flutter/material.dart';
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
      if (mounted) _focusNodes[0].requestFocus();
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

  @override
  void didUpdateWidget(OtpVerifyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.email == widget.email) return;
    for (final controller in _controllers) {
      controller.clear();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  Future<void> _resendOtp() async {
    final email = widget.email;
    final sent = await ref.read(otpControllerProvider(email).notifier).resend();
    if (mounted && widget.email == email && sent) {
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
    final email = widget.email;
    final success =
        await ref.read(otpControllerProvider(email).notifier).submit(_otp);
    if (!mounted ||
        widget.email != email ||
        success ||
        ref.read(otpControllerProvider(email)).error == null) {
      return;
    }
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {});
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
          flow: ref.watch(otpControllerProvider(widget.email)),
          controllers: _controllers,
          focusNodes: _focusNodes,
          onDigitChanged: _onDigitChanged,
          otp: _otp,
          onVerify: _verify,
          onResend: _resendOtp,
          email: widget.email),
    );
  }
}
