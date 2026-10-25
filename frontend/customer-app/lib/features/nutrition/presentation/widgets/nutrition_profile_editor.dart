import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/health_profile_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_flow_model.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';

import 'nutrition_health_form.dart';
import 'nutrition_patient_intro.dart';
import 'nutrition_personalization_requirement.dart';

class NutritionProfileEditor extends StatelessWidget {
  const NutritionProfileEditor({
    super.key,
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.plannedDate,
    required this.session,
    required this.health,
    required this.flow,
    required this.dirty,
    required this.onDirtyChanged,
    required this.onSave,
    required this.onAssess,
    this.result,
  });

  final String beneficiaryId;
  final String? beneficiaryName;
  final DateTime plannedDate;
  final int session;
  final HealthProfileModel health;
  final NutritionFlow flow;
  final bool dirty;
  final ValueChanged<bool> onDirtyChanged;
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback onAssess;
  final Widget? result;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.section),
        children: [
          NutritionPatientIntro(name: beneficiaryName, editing: true),
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Tạo thực đơn cho ngày ${formatDate(plannedDate, padded: true)}'),
          if (flow.error != null) ...[
            const SizedBox(height: AppSpacing.compact),
            Text(flow.error!, style: const TextStyle(color: AppColors.error)),
          ],
          if (flow.loading) const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          NutritionHealthForm(
            key: ValueKey('health-$beneficiaryId-${health.revision}-$session'),
            health: health,
            enabled: !flow.loading,
            onDirtyChanged: onDirtyChanged,
            onSave: onSave,
          ),
          const SizedBox(height: AppSpacing.compact),
          NutritionPersonalizationRequirement(readiness: flow.readiness),
          const SizedBox(height: AppSpacing.compact),
          if (dirty)
            const Text(
              'Lưu phần thông tin đã cập nhật trước khi kiểm tra và xem gợi ý.',
            ),
          FilledButton.icon(
            onPressed: !flow.canAssess || dirty ? null : onAssess,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Kiểm tra thông tin'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: !flow.canAssess || dirty ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: AppSpacing.lg),
            result!,
          ],
        ],
      );
}
