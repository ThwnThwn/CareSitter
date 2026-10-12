import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_show_complete_shift_dialog_content.dart';
import 'package:flutter/material.dart';

class BookingDetailShowCompleteShiftDialogContentInner extends StatelessWidget {
  const BookingDetailShowCompleteShiftDialogContentInner(
      {super.key, required this.callbackAction1});
  final Future<void> Function() callbackAction1;

  @override
  Widget build(BuildContext context) =>
      BookingDetailShowCompleteShiftDialogContent(
          callbackAction2: callbackAction1);
}
