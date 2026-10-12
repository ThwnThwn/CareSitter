import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';

class RegistrationTermsChoice extends StatelessWidget {
  const RegistrationTermsChoice(
      {super.key,
      required this.agreed,
      required this.submitting,
      required this.callbackAction1});
  final bool agreed;
  final bool submitting;
  final void Function(bool?) callbackAction1;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: agreed,
        onChanged: submitting ? null : callbackAction1,
        title: const Text(
          'Tôi đồng ý với điều khoản sử dụng và chính sách bảo mật.',
          style: TextStyle(fontSize: AppFontSizes.s13, height: 1.35),
        ),
      );
}
