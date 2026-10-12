import 'booking_detail_screen_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingCompletedActions extends StatelessWidget {
  const BookingCompletedActions(
      {super.key, required this.onComplete, required this.onDispute});
  final void Function() onComplete;
  final void Function() onDispute;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BookingDetailScreenStatusBanner(
                message:
                    'Caregiver đã gửi yêu cầu kết thúc ca. Hãy xác nhận để hoàn tất.'),
            const SizedBox(height: AppSpacing.control),
            ElevatedButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Đã hoàn thành'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.control),
            OutlinedButton.icon(
              onPressed: onDispute,
              icon:
                  const Icon(Icons.report_problem_outlined, color: AppColors.error),
              label: const Text('Có vấn đề với ca chăm sóc',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
            ),
          ]);
}
