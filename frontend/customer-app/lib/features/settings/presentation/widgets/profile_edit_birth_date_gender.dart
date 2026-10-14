import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ProfileEditBirthDateGender extends StatelessWidget {
  const ProfileEditBirthDateGender(
      {super.key,
      required this.dobCtrl,
      required this.selectDate,
      required this.gender,
      required this.onGenderChanged});
  final TextEditingController dobCtrl;
  final VoidCallback selectDate;
  final String gender;
  final void Function(String?) onGenderChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: dobCtrl,
              readOnly: true,
              onTap: selectDate,
              decoration: const InputDecoration(
                labelText: 'Ngày sinh',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(
                labelText: 'Giới tính',
                prefixIcon: Icon(Icons.people_outline),
              ),
              items: const [
                DropdownMenuItem(value: 'MALE', child: Text('Nam')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
                DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                DropdownMenuItem(value: 'UNSPECIFIED', child: Text('Không rõ')),
              ],
              onChanged: onGenderChanged,
            ),
          ),
        ],
      );
}
