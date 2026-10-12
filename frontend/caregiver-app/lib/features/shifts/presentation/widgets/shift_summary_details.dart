import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftSummaryDetails extends StatelessWidget {
  const ShiftSummaryDetails(
      {super.key,
      required this.buildSummaryRow,
      required this.beneficiaryName,
      required this.duration,
      required this.completedTasks,
      required this.totalTasks,
      required this.checkoutPendingReview,
      required this.caregiverEarning});
  final Widget Function(
      {required IconData icon,
      bool isBold,
      required String label,
      required String value,
      Color? valueColor}) buildSummaryRow;
  final String beneficiaryName;
  final String duration;
  final int completedTasks;
  final int totalTasks;
  final bool checkoutPendingReview;
  final double caregiverEarning;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            buildSummaryRow(
              icon: Icons.person_outline_rounded,
              label: 'Người được chăm sóc',
              value: beneficiaryName,
            ),
            const Divider(height: 24),
            buildSummaryRow(
              icon: Icons.timer_outlined,
              label: 'Thời gian chăm sóc',
              value: duration,
            ),
            const Divider(height: 24),
            buildSummaryRow(
              icon: Icons.task_alt_rounded,
              label: 'Công việc hoàn thành',
              value: '$completedTasks/$totalTasks việc',
              valueColor: AppColors.success,
            ),
            const Divider(height: 24),
            buildSummaryRow(
              icon: Icons.monetization_on_outlined,
              label: checkoutPendingReview
                  ? 'Thu nhập dự kiến'
                  : 'Thu nhập nhận được',
              value:
                  '${formatVnd(caregiverEarning, separator: ',', suffix: '', round: true)} đ',
              valueColor: checkoutPendingReview
                  ? AppColors.textSecondary
                  : AppColors.primary,
              isBold: true,
            ),
          ],
        ),
      );
}
