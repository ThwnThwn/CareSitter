import 'package:flutter/material.dart';

class ProfileEditSaveButton extends StatelessWidget {
  const ProfileEditSaveButton(
      {super.key, required this.busy, required this.onSave});
  final bool busy;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => ElevatedButton(
      onPressed: busy ? null : onSave,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
          : const Text('Lưu thay đổi'));
}
