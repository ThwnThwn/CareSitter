import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingDetailShowCompleteShiftDialogButton extends StatelessWidget {
  const BookingDetailShowCompleteShiftDialogButton(
      {super.key, required this.action1});
  final Future<void> Function() action1;
  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
        onPressed: action1,
        child: const Text('Xác nhận'),
      );
}
