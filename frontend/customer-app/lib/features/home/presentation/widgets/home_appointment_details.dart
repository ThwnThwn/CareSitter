import 'package:caresitter_customer/features/home/presentation/widgets/home_appointment_trailing_status.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeAppointmentDetails extends StatelessWidget {
  const HomeAppointmentDetails(
      {super.key,
      required this.initials,
      required this.compactLayout,
      required this.statusBadge,
      required this.appointmentDetails});
  final String initials;
  final Widget Function({required bool includeStatus}) appointmentDetails;
  final bool compactLayout;
  final Widget statusBadge;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.inset),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                initials.isNotEmpty ? initials : 'CV',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
              child: appointmentDetails(includeStatus: compactLayout),
            ),
            if (!compactLayout)
              HomeAppointmentTrailingStatus(statusBadge: statusBadge),
          ],
        ),
      );
}
