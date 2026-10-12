import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingBottomActionBarFieldsBody extends StatelessWidget {
  const ShiftTrackingBottomActionBarFieldsBody(
      {super.key,
      required this.callbackAction1,
      required this.callbackAction2});
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: callbackAction1,
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Xác nhận kết thúc ca',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: callbackAction2,
            icon: const Icon(Icons.report_problem_outlined,
                color: AppColors.error, size: 15),
            label: const Text('Báo cáo vấn đề',
                style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        ],
      );
}
