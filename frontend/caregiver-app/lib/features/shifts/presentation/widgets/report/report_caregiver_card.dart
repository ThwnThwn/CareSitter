import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_caregiver_identity.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_caregiver_earning.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_caregiver_avatar.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Card hiển thị thông tin người chăm sóc và chi phí ca.
class ReportCaregiverCard extends StatelessWidget {
  final String caregiverName;
  final double caregiverEarning;

  const ReportCaregiverCard({
    super.key,
    required this.caregiverName,
    required this.caregiverEarning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.section),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Avatar
          ReportCaregiverAvatar(caregiverName: caregiverName),
          const SizedBox(width: AppSpacing.inset),
          ReportCaregiverIdentity(caregiverName: caregiverName),
          // Earning
          ReportCaregiverEarning(caregiverEarning: caregiverEarning),
        ],
      ),
    );
  }
}
