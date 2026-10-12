import 'package:flutter/material.dart';

class RegistrationEmailField extends StatelessWidget {
  const RegistrationEmailField(
      {super.key, required this.emailController, required this.validEmail});
  final TextEditingController emailController;
  final String? Function(String?) validEmail;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        validator: validEmail,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.email_outlined),
        ),
      );
}
