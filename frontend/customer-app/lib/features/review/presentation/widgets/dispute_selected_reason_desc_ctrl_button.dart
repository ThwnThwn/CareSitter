import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class DisputeSelectedReasonDescCtrlButton extends StatelessWidget {
  const DisputeSelectedReasonDescCtrlButton(
      {super.key,
      required this.selectedReason,
      required this.descCtrl,
      required this.isSubmitting,
      required this.submit});
  final String? selectedReason;
  final TextEditingController descCtrl;
  final bool isSubmitting;
  final Future<void> Function() submit;
  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: selectedReason != null &&
                descCtrl.text.length >= 20 &&
                !isSubmitting
            ? submit
            : null,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Text('Gửi khiếu nại',
                style: TextStyle(color: Colors.white)),
      );
}
