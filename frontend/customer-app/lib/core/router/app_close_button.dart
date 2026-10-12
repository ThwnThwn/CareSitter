import 'package:caresitter_customer/core/router/app_back_button_presentation_helpers.dart';
import 'package:flutter/material.dart';

class AppCloseButton extends StatelessWidget {
  final String fallbackRoute;
  final Color? color;
  final VoidCallback? onPressed;

  const AppCloseButton({
    super.key,
    required this.fallbackRoute,
    this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CloseButton(
      color: color,
      onPressed:
          onPressed ?? () => popOrGo(context, fallbackRoute: fallbackRoute),
    );
  }
}
