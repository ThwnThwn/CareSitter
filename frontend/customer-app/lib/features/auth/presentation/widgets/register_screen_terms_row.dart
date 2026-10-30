import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/config/legal_links.dart';
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
                  borderRadius: BorderRadius.circular(AppRadius.checkbox)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: AppSpacing.control),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tôi đồng ý với các quy định của CareSitter:',
                  style: TextStyle(
                    fontSize: AppFontSizes.s13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.xs,
                  children: [
                    _LegalTextButton(
                      label: 'Điều khoản dịch vụ',
                      open: LegalLinks.openTerms,
                    ),
                    Text('và',
                        style: TextStyle(
                            fontSize: AppFontSizes.s13,
                            color: AppColors.textSecondary)),
                    _LegalTextButton(
                      label: 'Chính sách quyền riêng tư',
                      open: LegalLinks.openPrivacy,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalTextButton extends StatelessWidget {
  const _LegalTextButton({required this.label, required this.open});

  final String label;
  final Future<bool> Function() open;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () async {
          final opened = await open();
          if (!opened && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Chưa cấu hình đường dẫn chính sách.')),
            );
          }
        },
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 0),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
            fontSize: AppFontSizes.s13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
        child: Text(label),
      );
}
