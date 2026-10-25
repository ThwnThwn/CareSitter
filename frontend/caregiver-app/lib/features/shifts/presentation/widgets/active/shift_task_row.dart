import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_action_policy.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_action_feedback.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_photo_picker.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_editor.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_evidence.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_labels.dart';

class ShiftTaskRow extends ConsumerWidget {
  const ShiftTaskRow({super.key, required this.booking, required this.task});

  final ShiftModel booking;
  final CareTaskModel task;

  Future<void> _photo(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(shiftActiveProvider(booking.id).notifier);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Chụp ảnh minh chứng'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || source == null || !controller.mounted) return;
    final image = await const ShiftPhotoPicker().pick(context, source);
    if (!context.mounted || image == null || !controller.mounted) return;
    final result = await controller.uploadTaskPhoto(task.id, image);
    if (context.mounted) {
      showShiftActionResult(context, result, success: 'Đã tải ảnh minh chứng.');
    }
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(shiftActiveProvider(booking.id).notifier)
        .completeTask(task.id);
    if (context.mounted) showShiftActionResult(context, result);
  }

  void _skip(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => ShiftTaskEditor(
          bookingId: booking.id,
          taskId: task.id,
          mode: ShiftTaskEditorMode.skip,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(
      shiftActiveProvider(booking.id).select(
        (state) => state.busy.contains('task:${task.id}'),
      ),
    );
    final interactive = booking.canWorkChecklist && !task.isTerminal;
    final complete = interactive && !busy;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.compact,
              AppSpacing.control,
              AppSpacing.compact,
              AppSpacing.tight,
            ),
            child: _TaskSummary(
              task: task,
              busy: busy,
              onComplete: complete ? () => _complete(context, ref) : null,
            ),
          ),
          if (task.photoUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.compact,
                vertical: AppSpacing.sm,
              ),
              child: ShiftTaskEvidence(urls: task.photoUrls),
            ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: _TaskActions(
              task: task,
              onPhoto: interactive && !busy ? () => _photo(context, ref) : null,
              onComplete: complete ? () => _complete(context, ref) : null,
              onSkip: interactive && !busy ? () => _skip(context) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSummary extends StatelessWidget {
  const _TaskSummary({
    required this.task,
    required this.busy,
    required this.onComplete,
  });

  final CareTaskModel task;
  final bool busy;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 44,
            child: IconButton(
              tooltip: task.isCompleted
                  ? 'Đã hoàn thành'
                  : task.isSkipped
                      ? 'Đã bỏ qua'
                      : 'Đánh dấu hoàn thành',
              onPressed: onComplete,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      task.isCompleted
                          ? Icons.check_circle_rounded
                          : task.isSkipped
                              ? Icons.remove_circle_outline_rounded
                              : Icons.radio_button_unchecked_rounded,
                      color: task.isCompleted
                          ? AppColors.success
                          : AppColors.border,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFontSizes.s14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (task.description?.isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    task.description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSizes.s12,
                      height: 1.35,
                    ),
                  ),
                ],
                ShiftTaskLabels(task: task),
              ],
            ),
          ),
        ],
      );
}

class _TaskActions extends StatelessWidget {
  const _TaskActions({
    required this.task,
    required this.onPhoto,
    required this.onComplete,
    required this.onSkip,
  });

  final CareTaskModel task;
  final VoidCallback? onPhoto;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: AppSpacing.xxs,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: onPhoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Minh chứng'),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: onComplete,
            child: Text(task.isCompleted ? 'Đã xong' : 'Hoàn thành'),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: onSkip,
            child: const Text('Bỏ qua'),
          ),
        ],
      );
}
