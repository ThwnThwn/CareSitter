import 'package:flutter/material.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/features/shifts/presentation/models/shift_action_result.dart';

bool showShiftActionResult(BuildContext context, ShiftActionResult result,
    {String? success}) {
  if (!context.mounted) return false;
  if (result is ShiftActionFailure) {
    AppToast.error(
      context,
      result.message,
      title: 'Chưa thể cập nhật ca',
    );
  } else if (result is ShiftActionSuccess && success != null) {
    AppToast.success(context, success);
  }
  return result is ShiftActionSuccess;
}
