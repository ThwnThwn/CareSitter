import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RegisterScreenTermsRow extends StatelessWidget {
  const RegisterScreenTermsRow(
      {super.key, required this.onChanged, required this.agreedToTerms});
  final ValueChanged<bool> onChanged;
  final bool agreedToTerms;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!agreedToTerms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: agreedToTerms,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                    fontSize: AppFontSizes.s13,
                    color: AppColors.textSecondary,
                    height: 1.4),
                children: [
                  TextSpan(text: 'Tôi đồng ý với '),
                  TextSpan(
                    text: 'Điều khoản sử dụng',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: ' và '),
                  TextSpan(
                    text: 'Chính sách bảo mật',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: ' của CareSitter'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
