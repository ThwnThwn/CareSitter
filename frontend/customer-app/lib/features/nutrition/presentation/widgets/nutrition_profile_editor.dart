import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/health_profile_model.dart';
import 'package:caresitter_customer/features/nutrition/presentation/models/nutrition_flow_model.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import '../../../../core/utils/date_formatter.dart';

import 'nutrition_health_form.dart';
import 'nutrition_patient_intro.dart';

class NutritionProfileEditor extends StatefulWidget {
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
  State<NutritionProfileEditor> createState() => _NutritionProfileEditorState();
}

class _NutritionProfileEditorState extends State<NutritionProfileEditor> {
  final _formKey = GlobalKey<NutritionHealthFormState>();

  void _check() {
    final readiness = _formKey.currentState?.validate();
    if (readiness == null) return;
    if (!readiness.isReady) {
      AppToast.error(context, readiness.missingFields.first,
          title: 'Vui lòng bổ sung thông tin');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.revealFirstError();
      });
    } else if (widget.flow.canAssess || widget.dirty) {
      widget.onSave(_formKey.currentState!.changes);
    } else {
      AppToast.info(context, 'Chưa thể kiểm tra thông tin. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.section,
          AppSpacing.section,
          AppSpacing.section,
          AppSpacing.hero + AppSpacing.xxl,
        ),
        children: [
          NutritionPatientIntro(name: widget.beneficiaryName, editing: true),
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Tạo thực đơn cho ngày ${formatDate(widget.plannedDate, padded: true)}'),
          if (widget.flow.error != null) ...[
            const SizedBox(height: AppSpacing.compact),
            Text(widget.flow.error!,
                style: const TextStyle(color: AppColors.error)),
          ],
          if (widget.flow.loading) const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          KeyedSubtree(
            key: ValueKey(
                'health-${widget.beneficiaryId}-${widget.health.revision}-${widget.session}'),
            child: NutritionHealthForm(
              key: _formKey,
              health: widget.health,
              missingFields: widget.dirty ||
                      widget.flow.resource?.result.decision.state !=
                          'needs_information'
                  ? const []
                  : [
                      ...widget.flow.resource!.result.decision.missingFields,
                      if (widget.flow.resource!.result.decision.conflicts
                          .contains('allergy_sources_conflict'))
                        'foodAllergyStatus',
                      if (widget.flow.resource!.result.decision.conflicts
                          .contains('condition_sources_conflict'))
                        'conditionsStatus',
                      if (widget.flow.resource!.result.decision.conflicts
                          .contains('medication_sources_conflict'))
                        'medicationsStatus',
                    ],
              guidanceFields: widget.dirty ||
                      widget.flow.resource?.result.decision.state !=
                          'needs_professional_guidance'
                  ? const []
                  : widget.flow.resource!.result.decision.requiredGuidance,
              enabled: !widget.flow.loading,
              onDirtyChanged: widget.onDirtyChanged,
              onSave: widget.onSave,
              showSaveButton: false,
            ),
          ),
          if (widget.flow.weekProgress == null &&
              (widget.dirty || widget.result == null)) ...[
            const SizedBox(height: AppSpacing.compact),
            FilledButton.icon(
              onPressed: widget.flow.loading ||
                      (!widget.flow.canAssess && !widget.dirty)
                  ? null
                  : _check,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(widget.dirty ? 'Lưu thông tin' : 'Tạo thực đơn'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: widget.flow.loading ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
            ),
          ],
          if (widget.result != null) ...[
            const SizedBox(height: AppSpacing.lg),
            widget.result!,
          ],
        ],
      );
}
