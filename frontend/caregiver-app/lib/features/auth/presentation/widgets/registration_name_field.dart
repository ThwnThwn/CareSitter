import 'package:flutter/material.dart';

class RegistrationNameField extends StatelessWidget {
  const RegistrationNameField(
      {super.key, required this.nameController, required this.requiredName});
  final TextEditingController nameController;
  final String? Function(String?) requiredName;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: nameController,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
        validator: requiredName,
        decoration: const InputDecoration(
          labelText: 'Họ và tên',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
      );
}
