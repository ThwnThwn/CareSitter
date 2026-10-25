import 'package:flutter/material.dart';

import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftTaskLabels extends StatelessWidget {
  const ShiftTaskLabels({super.key, required this.task});

  final CareTaskModel task;

  @override
  Widget build(BuildContext context) {
    final visible = task.isRequired || task.isAdHoc || task.isSkipped;
    if (!visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          if (task.isRequired) const _TaskLabel('● Công việc bắt buộc'),
          if (task.isAdHoc)
            const _TaskLabel('Đề xuất thêm', tone: _LabelTone.suggested),
          if (task.isSkipped) _TaskLabel('Đã bỏ qua: ${task.skipReason ?? ''}'),
        ],
      ),
    );
  }
}

class _TaskLabel extends StatelessWidget {
  const _TaskLabel(this.label, {this.tone = _LabelTone.required});

  final String label;
  final _LabelTone tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: switch (tone) {
            _LabelTone.required => AppColors.authErrorSurface,
            _LabelTone.suggested => AppColors.primaryContainer,
          },
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: switch (tone) {
              _LabelTone.required => AppColors.error,
              _LabelTone.suggested => AppColors.primary,
            },
            fontSize: AppFontSizes.s10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

enum _LabelTone { required, suggested }
