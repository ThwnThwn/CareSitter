import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class RegistrationConfirmField extends StatelessWidget {
  const RegistrationConfirmField(
      {super.key,
      required this.buildPasswordField,
      required this.confirmPassCtrl,
      required this.obscureConfirm,
      required this.callbackAction2,
      required this.validateConfirmPassword,
      required this.callbackAction3});
  final Widget Function(
      {required TextEditingController controller,
      required String label,
      required bool obscure,
      void Function(String)? onSubmitted,
      required void Function() onToggle,
      TextInputAction? textInputAction,
      String? Function(String?)? validator}) buildPasswordField;
  final TextEditingController confirmPassCtrl;
  final bool obscureConfirm;
  final void Function() callbackAction2;
  final String? Function(String?) validateConfirmPassword;
  final void Function(String) callbackAction3;

  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 6,
        child: buildPasswordField(
          controller: confirmPassCtrl,
          label: 'Xác nhận mật khẩu',
          obscure: obscureConfirm,
          onToggle: callbackAction2,
          validator: validateConfirmPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: callbackAction3,
        ),
      );
}
