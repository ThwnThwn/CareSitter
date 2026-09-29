import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_widgets.dart';
import 'package:caresitter_customer/features/auth/data/repositories/auth_repository.dart';

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
      await ref.read(authRepositoryProvider).requestOtp(phone);
      if (mounted) context.push('/auth/otp', extra: phone);
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
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 280),
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
                      right: -40,
                      top: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: 20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 60, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'CareSitter',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chăm sóc người thân, trao gửi yêu thương',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form ────────────────────────────
              Padding(
                padding: EdgeInsets.all(
                  isCompact ? AppSpacing.md : AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Nhập số điện thoại để nhận mã OTP xác nhận',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Phone field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: _validatePhone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.5,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Số điện thoại',
                          hintText: '0909 123 456',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '🇻🇳 +84',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      AppButton(
                        label: 'Gửi mã OTP',
                        onPressed: _requestOtp,
                        isLoading: _isLoading,
                        icon: Icons.send_rounded,
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      const Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.divider)),
                          SizedBox(width: 12),
                          Flexible(
                            flex: 6,
                            child: Text(
                              'Bằng cách tiếp tục, bạn đồng ý với',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textHint),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Divider(color: AppColors.divider)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Điều khoản & Chính sách'),
                              content: const SingleChildScrollView(
                                child: Text(
                                  'CareSitter cam kết bảo vệ thông tin cá nhân của bạn.\n\n'
                                  '• Thông tin của bạn chỉ dùng để cung cấp dịch vụ chăm sóc.\n'
                                  '• Chúng tôi không chia sẻ dữ liệu với bên thứ ba.\n'
                                  '• Bạn có thể yêu cầu xóa tài khoản bất kỳ lúc nào.\n\n'
                                  'Bằng cách tiếp tục, bạn đồng ý với các điều khoản trên.',
                                ),
                              ),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Đã hiểu'),
                                ),
                              ],
                            ),
                          ),
                          child: const Text(
                            'Điều khoản sử dụng & Chính sách bảo mật',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
