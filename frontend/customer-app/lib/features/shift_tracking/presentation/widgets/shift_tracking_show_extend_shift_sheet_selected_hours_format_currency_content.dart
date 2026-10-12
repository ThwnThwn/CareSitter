import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_show_extend_shift_sheet_selected_hours_format_currency_fields.dart';
import 'package:flutter/material.dart';

class ShiftTrackingShowExtendShiftSheetSelectedHoursFormatCurrencyContent
    extends StatelessWidget {
  const ShiftTrackingShowExtendShiftSheetSelectedHoursFormatCurrencyContent(
      {super.key,
      required this.selectedHours,
      required this.formatCurrency,
      required this.effectiveHourlyRate,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3});
  final int selectedHours;
  final String Function(double) formatCurrency;
  final double effectiveHourlyRate;
  final void Function() callbackAction1;
  final void Function() callbackAction2;
  final void Function() callbackAction3;

  @override
  Widget build(BuildContext context) =>
      ShiftTrackingShowExtendShiftSheetSelectedHoursFormatCurrencyFields(
          selectedHours: selectedHours,
          onDecrease: callbackAction1,
          onIncrease: callbackAction2,
          formatCurrency: formatCurrency,
          effectiveHourlyRate: effectiveHourlyRate,
          action1: callbackAction3);
}
