import 'package:flutter/material.dart';

class ShiftDestinationAttribution extends StatelessWidget {
  const ShiftDestinationAttribution({super.key, required this.callbackAction1});
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: callbackAction1,
            child: const SizedBox.expand(),
          ),
        ),
      );
}
