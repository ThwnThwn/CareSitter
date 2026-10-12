import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_show_extend_shift_sheet_selected_hours_format_currency_content.dart';
import 'package:flutter/material.dart';

class BookingDetailShowExtendShiftSheetSelectedHoursFormatCurrencyContentBody
    extends StatelessWidget {
  const BookingDetailShowExtendShiftSheetSelectedHoursFormatCurrencyContentBody(
      {super.key,
      required this.selectedHours,
      required this.formatCurrency,
      required this.effectiveHourlyRate,
      required this.callbackAction1});
  final int selectedHours;
  final String Function(double) formatCurrency;
  final double effectiveHourlyRate;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) =>
      BookingDetailShowExtendShiftSheetSelectedHoursFormatCurrencyContent(
          selectedHours: selectedHours,
          formatCurrency: formatCurrency,
          effectiveHourlyRate: effectiveHourlyRate,
          callbackAction2: callbackAction1);
}
