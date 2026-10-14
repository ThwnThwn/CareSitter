import 'package:caregiver_app/features/shifts/presentation/widgets/shift_summary_details.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_summary_report_action.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_summary_status_icon.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_summary_status_label.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xl),
              // Success Header
              ShiftSummaryStatusIcon(
                  checkoutPendingReview: checkoutPendingReview),
              const SizedBox(height: AppSpacing.lg),
              ShiftSummaryStatusLabel(
                  checkoutPendingReview: checkoutPendingReview),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Báo cáo tổng kết ca $bookingId',
                style: const TextStyle(
                    fontSize: AppFontSizes.s14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Summary Stats Card
              ShiftSummaryDetails(
                  beneficiaryName: beneficiaryName,
                  duration: duration,
                  completedTasks: completedTasks,
                  totalTasks: totalTasks,
                  checkoutPendingReview: checkoutPendingReview,
                  caregiverEarning: caregiverEarning),
              const SizedBox(height: AppSpacing.xxl),

              // Button — View Customer Report
              ShiftSummaryReportAction(callbackAction1: () {
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
              }),
              const SizedBox(height: AppSpacing.inset),

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
}
