import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_show_extend_shift_sheet_selected_hours_format_currency_fields.dart';
import 'package:flutter/material.dart';

class BookingDetailShowExtendShiftSheetSelectedHoursFormatCurrencyContent
    extends StatelessWidget {
  const BookingDetailShowExtendShiftSheetSelectedHoursFormatCurrencyContent(
      {super.key,
      required this.selectedHours,
      required this.formatCurrency,
      required this.effectiveHourlyRate,
      required this.callbackAction2});
  final int selectedHours;
  final String Function(double) formatCurrency;
  final double effectiveHourlyRate;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) =>
      BookingDetailShowExtendShiftSheetSelectedHoursFormatCurrencyFields(
          selectedHours: selectedHours,
          onDecrease: callbackAction2,
          onIncrease: callbackAction2,
          formatCurrency: formatCurrency,
          effectiveHourlyRate: effectiveHourlyRate,
          action1: callbackAction2);
}
