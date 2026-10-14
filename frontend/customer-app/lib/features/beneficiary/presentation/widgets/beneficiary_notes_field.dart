import 'package:flutter/material.dart';

class BeneficiaryNotesField extends StatelessWidget {
  const BeneficiaryNotesField({super.key, required this.notesCtrl});
  final TextEditingController notesCtrl;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: notesCtrl,
        maxLines: 3,
        maxLength: 500,
        decoration: const InputDecoration(
          hintText: 'Sở thích, thói quen, lưu ý an toàn, chế độ ăn đặc biệt...',
        ),
      );
}
