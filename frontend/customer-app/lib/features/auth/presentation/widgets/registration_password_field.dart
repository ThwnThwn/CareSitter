import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class RegistrationPasswordField extends StatelessWidget {
  const RegistrationPasswordField(
      {super.key,
      required this.buildPasswordField,
      required this.passCtrl,
      required this.obscurePass,
      required this.callbackAction1,
      required this.validatePassword});
  final Widget Function(
      {required TextEditingController controller,
      required String label,
      required bool obscure,
      void Function(String)? onSubmitted,
      required void Function() onToggle,
      TextInputAction? textInputAction,
      String? Function(String?)? validator}) buildPasswordField;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final void Function() callbackAction1;
  final String? Function(String?) validatePassword;

  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 5,
        child: buildPasswordField(
          controller: passCtrl,
          label: 'Mật khẩu',
          obscure: obscurePass,
          onToggle: callbackAction1,
          validator: validatePassword,
          textInputAction: TextInputAction.next,
        ),
      );
}
