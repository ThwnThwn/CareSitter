import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegistrationPhoneField extends StatelessWidget {
  const RegistrationPhoneField(
      {super.key, required this.phoneController, required this.validPhone});
  final TextEditingController phoneController;
  final String? Function(String?) validPhone;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        validator: validPhone,
        decoration: const InputDecoration(
          labelText: 'Số điện thoại',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
      );
}
