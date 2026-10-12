import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailBody extends StatelessWidget {
  const ShiftDetailBody(
      {super.key,
      required this.buildStatusBanner,
      required this.booking,
      required this.buildEarningsSummaryCard,
      required this.buildScheduleInfo,
      required this.buildSectionHeader,
      required this.buildCareRecipientCard,
      required this.beneficiary,
      required this.buildLocationCard,
      required this.buildChecklistCard,
      required this.buildSafetyGuidelinesCard,
      required this.isPending,
      required this.buildAcceptRejectButtons,
      required this.ref,
      required this.isEnRoute,
      required this.buildEnRouteBanner,
      required this.isInProgress,
      required this.buildGoToActiveShiftButton,
      required this.isCompleted,
      required this.buildCompletedShiftCard});
  final Widget Function(ShiftModel) buildStatusBanner;
  final ShiftModel booking;
  final Widget Function(ShiftModel) buildEarningsSummaryCard;
  final Widget Function(ShiftModel) buildScheduleInfo;
  final Widget Function(String) buildSectionHeader;
  final Widget Function(ShiftBeneficiaryModel, ShiftModel)
      buildCareRecipientCard;
  final ShiftBeneficiaryModel beneficiary;
  final Widget Function(BuildContext, ShiftModel) buildLocationCard;
  final Widget Function(ShiftModel, ShiftBeneficiaryModel) buildChecklistCard;
  final Widget Function(ShiftBeneficiaryModel) buildSafetyGuidelinesCard;
  final bool isPending;
  final Widget Function(BuildContext, WidgetRef, String)
      buildAcceptRejectButtons;
  final WidgetRef ref;
  final bool isEnRoute;
  final Widget Function(BuildContext, WidgetRef, ShiftModel) buildEnRouteBanner;
  final bool isInProgress;
  final Widget Function(BuildContext, String) buildGoToActiveShiftButton;
  final bool isCompleted;
  final Widget Function(ShiftModel) buildCompletedShiftCard;

  @override
  Widget build(BuildContext context) => Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.compact),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildStatusBanner(booking),
              const SizedBox(height: AppSpacing.compact),
              buildEarningsSummaryCard(booking),
              const SizedBox(height: AppSpacing.compact),
              buildScheduleInfo(booking),
              const SizedBox(height: AppSpacing.md),
              buildSectionHeader('Người được chăm sóc'),
              const SizedBox(height: AppSpacing.sm),
              buildCareRecipientCard(beneficiary, booking),
              const SizedBox(height: AppSpacing.md),
              buildSectionHeader('Địa điểm làm việc'),
              const SizedBox(height: AppSpacing.sm),
              buildLocationCard(context, booking),
              const SizedBox(height: AppSpacing.md),
              buildSectionHeader('Công việc cần làm'),
              const SizedBox(height: AppSpacing.sm),
              buildChecklistCard(booking, beneficiary),
              const SizedBox(height: AppSpacing.md),
              buildSafetyGuidelinesCard(beneficiary),
              const SizedBox(height: AppSpacing.md),
              if (isPending) buildAcceptRejectButtons(context, ref, booking.id),
              if (isEnRoute) buildEnRouteBanner(context, ref, booking),
              if (isInProgress) buildGoToActiveShiftButton(context, booking.id),
              if (isCompleted) buildCompletedShiftCard(booking),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
}
