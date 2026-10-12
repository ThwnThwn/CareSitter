import 'package:caresitter_customer/features/auth/presentation/widgets/phone_login_field.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/phone_login_policy_dialog.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_widgets.dart';

class PhoneLoginForm extends StatelessWidget {
  const PhoneLoginForm(
      {super.key,
      required this.isCompact,
      required this.formKey,
      required this.phoneController,
      required this.validatePhone,
      required this.requestOtp,
      required this.isLoading});
  final bool isCompact;
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final String? Function(String?) validatePhone;
  final Future<void> Function() requestOtp;
  final bool isLoading;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(
          isCompact ? AppSpacing.md : AppSpacing.lg,
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Đăng nhập',
                style: TextStyle(
                  fontSize: AppFontSizes.s24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.tight),
              const Text(
                'Nhập số điện thoại để nhận mã OTP xác nhận',
                style: TextStyle(
                  fontSize: AppFontSizes.s14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.wide),

              // Phone field
              PhoneLoginField(
                  phoneController: phoneController,
                  validatePhone: validatePhone),
              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: 'Gửi mã OTP',
                onPressed: requestOtp,
                isLoading: isLoading,
                icon: Icons.send_rounded,
              ),
              const SizedBox(height: AppSpacing.section),

              // Divider
              const Row(
                children: [
                  Expanded(child: Divider(color: AppColors.divider)),
                  SizedBox(width: AppSpacing.compact),
                  Flexible(
                    flex: 6,
                    child: Text(
                      'Bằng cách tiếp tục, bạn đồng ý với',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: AppFontSizes.s11,
                          color: AppColors.textHint),
                    ),
                  ),
                  SizedBox(width: AppSpacing.compact),
                  Expanded(child: Divider(color: AppColors.divider)),
                ],
              ),
              const SizedBox(height: AppSpacing.compact),
              const PhoneLoginPolicyDialog(),
            ],
          ),
        ),
      );
}
