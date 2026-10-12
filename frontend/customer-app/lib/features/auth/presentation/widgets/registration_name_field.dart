import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class RegistrationNameField extends StatelessWidget {
  const RegistrationNameField(
      {super.key,
      required this.buildField,
      required this.nameCtrl,
      required this.validateName});
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
  final TextEditingController nameCtrl;
  final String? Function(String?) validateName;

  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 2,
        child: buildField(
          controller: nameCtrl,
          label: 'Họ và tên',
          hint: 'Nguyễn Văn A',
          icon: Icons.person_outline_rounded,
          validator: validateName,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
        ),
      );
}
