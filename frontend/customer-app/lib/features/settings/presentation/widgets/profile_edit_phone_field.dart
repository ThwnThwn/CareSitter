import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class ProfileEditPhoneField extends StatelessWidget {
  const ProfileEditPhoneField({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: profile.phone,
        enabled: false,
        decoration: const InputDecoration(
          labelText: 'Số điện thoại (Cố định)',
          prefixIcon: Icon(Icons.phone_outlined),
          suffixIcon: Icon(Icons.lock_outline, size: 18),
        ),
      );
}
