import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class ShiftSummaryScreen extends StatelessWidget {
  final String bookingId;
  final String beneficiaryName;
  final String caregiverName;
  final double caregiverEarning;
  final int completedTasks;
  final int totalTasks;
  final String duration;
  final String checkInTime;
  final String caregiverNote;
  final List<String> taskPhotos;
  final bool checkoutPendingReview;

  const ShiftSummaryScreen({
    super.key,
    required this.bookingId,
    required this.beneficiaryName,
    this.caregiverName = 'Người chăm sóc',
    required this.caregiverEarning,
    required this.completedTasks,
    required this.totalTasks,
    required this.duration,
    this.checkInTime = '08:05',
    this.caregiverNote = '',
    this.taskPhotos = const [],
    this.checkoutPendingReview = false,
  });

  String _formatCurrency(double amount) {
    final str = amount.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Success Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  checkoutPendingReview
                      ? Icons.hourglass_top_rounded
                      : Icons.check_circle_rounded,
                  color: checkoutPendingReview
                      ? AppColors.warning
                      : AppColors.success,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                checkoutPendingReview
                    ? 'Đã gửi yêu cầu checkout'
                    : 'Hoàn thành ca làm việc!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Báo cáo tổng kết ca $bookingId',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              // Summary Stats Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Khách hàng',
                      value: beneficiaryName,
                    ),
                    const Divider(height: 24),
                    _buildSummaryRow(
                      icon: Icons.timer_outlined,
                      label: 'Thời gian chăm sóc',
                      value: duration,
                    ),
                    const Divider(height: 24),
                    _buildSummaryRow(
                      icon: Icons.task_alt_rounded,
                      label: 'Công việc hoàn thành',
                      value: '$completedTasks/$totalTasks việc',
                      valueColor: AppColors.success,
                    ),
                    const Divider(height: 24),
                    _buildSummaryRow(
                      icon: Icons.monetization_on_outlined,
                      label: checkoutPendingReview
                          ? 'Thu nhập dự kiến'
                          : 'Thu nhập nhận được',
                      value: '${_formatCurrency(caregiverEarning)} đ',
                      valueColor: checkoutPendingReview
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Button — View Customer Report
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Xem báo cáo khách hàng'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  context.push(
                    '/shifts/$bookingId/customer-report',
                    extra: {
                      'beneficiaryName': beneficiaryName,
                      'caregiverName': caregiverName,
                      'caregiverEarning': caregiverEarning,
                      'completedTasks': completedTasks,
                      'totalTasks': totalTasks,
                      'duration': duration,
                      'checkInTime': checkInTime,
                      'caregiverNote': caregiverNote,
                      'taskPhotos': taskPhotos,
                    },
                  );
                },
              ),
              const SizedBox(height: 14),

              // Button to Home
              AppButton(
                label: 'Trở về Trang chủ',
                icon: Icons.home_rounded,
                onPressed: () {
                  context.go('/home');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
