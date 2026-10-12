import 'package:flutter/material.dart';

class DisputeDescCtrlContent extends StatelessWidget {
  const DisputeDescCtrlContent(
      {super.key, required this.descCtrl, required this.callbackAction2});
  final TextEditingController descCtrl;
  final void Function(String) callbackAction2;

  @override
  Widget build(BuildContext context) => TextField(
        controller: descCtrl,
        maxLines: 5,
        maxLength: 1000,
        onChanged: callbackAction2,
        decoration: const InputDecoration(
          hintText: 'Mô tả sự việc xảy ra một cách chi tiết và khách quan...',
        ),
      );
}
