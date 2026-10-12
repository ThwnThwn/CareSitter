import 'package:caregiver_app/core/theme/app_spacing.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_action_feedback.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_photo_picker.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_editor.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_evidence.dart';

class ShiftTaskRow extends ConsumerWidget {
  const ShiftTaskRow({super.key, required this.booking, required this.task});
  final ShiftModel booking;
  final CareTaskModel task;
  Future<void> _photo(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(shiftActiveProvider(booking.id).notifier);
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Chụp ảnh minh chứng'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera)),
              ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Chọn từ Thư viện'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
            ])));
    if (!context.mounted || source == null || !controller.mounted) return;
    final image = await const ShiftPhotoPicker().pick(context, source);
    if (!context.mounted || image == null || !controller.mounted) return;
    final result = await controller.uploadTaskPhoto(task.id, image);
    if (context.mounted) {
      showShiftActionResult(context, result, success: 'Đã tải ảnh minh chứng.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(shiftActiveProvider(booking.id)
        .select((s) => s.busy.contains('task:${task.id}')));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(AppSpacing.inset),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(task.isCompleted
                    ? Icons.check_circle
                    : task.isSkipped
                        ? Icons.cancel_outlined
                        : Icons.radio_button_unchecked),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text(task.title,
                        style: Theme.of(context).textTheme.titleSmall)),
              ]),
              if (task.description?.isNotEmpty == true) Text(task.description!),
              if (task.isRequired) const Text('Công việc bắt buộc'),
              if (task.requiresPhoto) const Text('Yêu cầu ảnh minh chứng'),
              if (task.isSkipped) Text('Đã bỏ qua: ${task.skipReason ?? ''}'),
              ShiftTaskEvidence(urls: task.photoUrls),
              if (booking.canWorkChecklist && !task.isTerminal)
                Wrap(spacing: AppSpacing.sm, children: [
                  TextButton.icon(
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Minh chứng'),
                      onPressed: busy ? null : () => _photo(context, ref)),
                  TextButton(
                      onPressed: busy || !task.canComplete
                          ? null
                          : () async {
                              final result = await ref
                                  .read(
                                      shiftActiveProvider(booking.id).notifier)
                                  .completeTask(task.id);
                              if (context.mounted) {
                                showShiftActionResult(context, result);
                              }
                            },
                      child: Text(busy ? 'Đang gửi…' : 'Hoàn thành')),
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => ShiftTaskEditor(
                                  bookingId: booking.id,
                                  taskId: task.id,
                                  mode: ShiftTaskEditorMode.skip)),
                      child: const Text('Bỏ qua')),
                ]),
            ])));
  }
}
