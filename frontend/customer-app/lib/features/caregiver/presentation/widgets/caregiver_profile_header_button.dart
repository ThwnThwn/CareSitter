import 'package:flutter/material.dart';

class CaregiverProfileHeaderButton extends StatelessWidget {
  const CaregiverProfileHeaderButton(
      {super.key, required this.callbackAction1});
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.share_outlined, color: Colors.white),
        onPressed: callbackAction1,
      );
}
