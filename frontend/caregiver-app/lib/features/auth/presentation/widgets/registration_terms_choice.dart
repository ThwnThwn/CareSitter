import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/config/legal_links.dart';
import 'package:flutter/material.dart';

class RegistrationTermsChoice extends StatelessWidget {
  const RegistrationTermsChoice(
      {super.key,
      required this.agreed,
      required this.submitting,
      required this.onChanged});
  final bool agreed;
  final bool submitting;
  final void Function(bool?) onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: agreed,
        onChanged: submitting ? null : onChanged,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tôi đồng ý với các quy định của CareSitter:',
              style: TextStyle(fontSize: AppFontSizes.s13, height: 1.35),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                _LegalTextButton(
                  label: 'Điều khoản dịch vụ',
                  open: LegalLinks.openTerms,
                ),
                Text('và', style: TextStyle(fontSize: AppFontSizes.s13)),
                _LegalTextButton(
                  label: 'Chính sách quyền riêng tư',
                  open: LegalLinks.openPrivacy,
                ),
              ],
            ),
          ],
        ),
      );
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
