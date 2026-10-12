export 'package:caresitter_customer/core/router/app_back_button_presentation_helpers.dart';
import 'package:caresitter_customer/core/router/app_back_button_presentation_helpers.dart';
export 'package:caresitter_customer/core/router/discard_changes_guard.dart';
export 'package:caresitter_customer/core/router/app_close_button.dart';

import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  final String fallbackRoute;
  final Color? color;
  final VoidCallback? onPressed;

  const AppBackButton({
    super.key,
    required this.fallbackRoute,
    this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BackButton(
      color: color,
      onPressed:
          onPressed ?? () => popOrGo(context, fallbackRoute: fallbackRoute),
    );
  }
}
