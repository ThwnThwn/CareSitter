import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'otp_digit_field.dart';

class OtpInputRow extends StatelessWidget {
  const OtpInputRow(
      {super.key,
      required this.controllers,
      required this.focusNodes,
      required this.onDigitChanged});
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int, String) onDigitChanged;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final width =
            math.min(46.0, (constraints.maxWidth - AppSpacing.xs * 5) / 6);
        return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var index = 0; index < 6; index++)
                SizedBox(
                    width: width,
                    child: OtpDigitField(
                      key: ValueKey('otp-digit-$index'),
                      controller: controllers[index],
                      focusNode: focusNodes[index],
                      onChanged: (value) => onDigitChanged(index, value),
                    )),
            ]);
      });
}
