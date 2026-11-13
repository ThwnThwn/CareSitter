import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Visual states shared by editable fields and search inputs.
abstract final class AppInputStyle {
  static const fillColor = Color(0xFFF2F5F4);
  static const radius = BorderRadius.all(Radius.circular(12));
  static const enabledBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide.none,
  );
  static const focusedBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
  );
  static const errorBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: AppColors.error, width: 1.5),
  );
}
