import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../models/nutrition_flow_model.dart';
import '../models/nutrition_menu_overview_model.dart';
import 'nutrition_inline_error.dart';
import 'nutrition_menu_overview.dart';
import 'nutrition_patient_intro.dart';

class NutritionMenuView extends StatelessWidget {
  const NutritionMenuView({
    super.key,
    required this.beneficiaryName,
    required this.flow,
    required this.result,
    this.onDateSelected,
    this.selectedDate,
    this.hasPlanForSelectedDate = true,
    this.isLoadingSelectedDate = false,
    this.dateError,
    this.onRetryDate,
    this.onCreatePlan,
  });

  final String? beneficiaryName;
  final NutritionFlow flow;
  final Widget result;
  final ValueChanged<DateTime>? onDateSelected;
  final DateTime? selectedDate;
  final bool hasPlanForSelectedDate;
  final bool isLoadingSelectedDate;
  final String? dateError;
  final VoidCallback? onRetryDate;
  final VoidCallback? onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final showPlan = !isLoadingSelectedDate &&
        hasPlanForSelectedDate &&
        flow.resource != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.section,
        AppSpacing.md,
        AppSpacing.section,
        AppSpacing.xl,
      ),
      children: [
        NutritionPatientIntro(name: beneficiaryName, editing: false),
        const SizedBox(height: AppSpacing.lg),
        NutritionMenuOverview(
          overview: NutritionMenuOverviewModel.fromFlow(
            flow,
            selectedDate: selectedDate,
            hasPlanForSelectedDate: showPlan,
            isLoadingSelectedDate: isLoadingSelectedDate,
          ),
          onDateSelected: onDateSelected,
        ),
        if (isLoadingSelectedDate) ...[
          const SizedBox(height: AppSpacing.compact),
          const LinearProgressIndicator(minHeight: 3),
        ] else if (dateError != null) ...[
          const SizedBox(height: AppSpacing.compact),
          NutritionInlineError(
            message: dateError!,
            onRetry: onRetryDate,
          ),
        ] else if (flow.error != null) ...[
          const SizedBox(height: AppSpacing.compact),
          NutritionInlineError(message: flow.error!),
        ] else if (!showPlan) ...[
          const SizedBox(height: AppSpacing.compact),
          _NoPlanNotice(
            date: selectedDate,
            onCreatePlan: onCreatePlan,
          ),
        ],
        if (flow.loading && !isLoadingSelectedDate) ...[
          const SizedBox(height: AppSpacing.compact),
          const LinearProgressIndicator(minHeight: 3),
        ],
        if (showPlan) ...[
          const SizedBox(height: AppSpacing.lg),
          result,
        ],
      ],
    );
  }
}

class _NoPlanNotice extends StatelessWidget {
  const _NoPlanNotice({required this.date, required this.onCreatePlan});

  final DateTime? date;
  final VoidCallback? onCreatePlan;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.event_busy_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date == null
                        ? 'Chưa có thực đơn cho ngày này'
                        : 'Chưa có thực đơn cho ngày ${formatDate(date!, padded: true)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Dùng hồ sơ hiện có để tạo thực đơn hoặc chọn một ngày khác.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                  if (onCreatePlan != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton.icon(
                      onPressed: onCreatePlan,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tạo thực đơn cho ngày này'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 40),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}
