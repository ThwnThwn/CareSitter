import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/presentation/models/shift_action_result.dart';

bool showShiftActionResult(BuildContext context, ShiftActionResult result,
    {String? success}) {
  if (!context.mounted) return false;
  if (result is ShiftActionFailure) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message), backgroundColor: AppColors.error));
  } else if (result is ShiftActionSuccess && success != null) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: AppColors.success));
  }
  return result is ShiftActionSuccess;
}
