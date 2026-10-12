import 'package:caresitter_customer/features/booking/presentation/widgets/booking_detail_show_complete_shift_dialog_content_body.dart';
import 'package:flutter/material.dart';

class BookingDetailShowCompleteShiftDialogContent extends StatelessWidget {
  const BookingDetailShowCompleteShiftDialogContent(
      {super.key, required this.callbackAction2});
  final Future<void> Function() callbackAction2;

  @override
  Widget build(BuildContext context) =>
      BookingDetailShowCompleteShiftDialogContentBody(
          callbackAction1: callbackAction2);
}
