import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class RegistrationEmailField extends StatelessWidget {
  const RegistrationEmailField(
      {super.key,
      required this.buildField,
      required this.emailCtrl,
      required this.validateEmail});
  final Widget Function(
      {required TextEditingController controller,
      required String hint,
      required IconData icon,
      List<TextInputFormatter>? inputFormatters,
      TextInputType? keyboardType,
      required String label,
      Widget? prefixWidget,
      TextCapitalization textCapitalization,
      TextInputAction? textInputAction,
      String? Function(String?)? validator}) buildField;
  final TextEditingController emailCtrl;
  final String? Function(String?) validateEmail;

  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 3,
        child: buildField(
          controller: emailCtrl,
          label: 'Email',
          hint: 'example@email.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: validateEmail,
          textInputAction: TextInputAction.next,
        ),
      );
}
