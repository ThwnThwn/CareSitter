import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_show_complete_shift_dialog_button.dart';
import 'package:flutter/material.dart';

class BookingDetailShowCompleteShiftDialogContentBody extends StatelessWidget {
  const BookingDetailShowCompleteShiftDialogContentBody(
      {super.key, required this.callbackAction1});
  final Future<void> Function() callbackAction1;

  @override
  Widget build(BuildContext context) =>
      BookingDetailShowCompleteShiftDialogButton(action1: callbackAction1);
}
