import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/core/utils/date_formatter.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_selectors.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_action_feedback.dart';

class ShiftCheckoutSection extends ConsumerWidget {
  const ShiftCheckoutSection({super.key, required this.booking});
  final ShiftModel booking;
  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final flow = ref.read(shiftActiveProvider(booking.id));
    final summary = ref.read(activeShiftSummaryProvider(booking.id));
    final result =
        await ref.read(shiftActiveProvider(booking.id).notifier).checkout();
    if (!context.mounted ||
        !showShiftActionResult(context, result,
            success: 'Đã gửi yêu cầu checkout đến khách hàng.')) {
      return;
    }
    final time = flow.startedAt;
    context.go('/shifts/${booking.id}/summary', extra: {
      'beneficiaryName': booking.beneficiaryName,
      'caregiverEarning': booking.caregiverEarning,
      'completedTasks': summary.completed,
      'skippedTasks': summary.skipped,
      'totalTasks': summary.total,
      'duration': booking.duration,
      'checkInTime': time == null ? '' : formatClock(time),
      'caregiverNote': flow.note,
      'taskPhotos': booking.tasks.expand((t) => t.photoUrls).toSet().toList(),
      'checkoutPendingReview': true,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(activeShiftSummaryProvider(booking.id));
    final busy = ref.watch(shiftActiveProvider(booking.id)
        .select((s) => s.busy.contains('checkout')));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (summary.pending > 0)
        Text('Còn ${summary.pending} công việc chưa hoàn thành hoặc bỏ qua.'),
      if (summary.requiredSkipped > 0)
        Text(
            '${summary.requiredSkipped} công việc bắt buộc bỏ qua. Ca sẽ được chuyển sang chế độ xét duyệt.'),
      const SizedBox(height: AppSpacing.compact),
      SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: summary.canCheckout && !busy
                  ? () => _submit(context, ref)
                  : null,
              child: Text(busy
                  ? 'Đang gửi yêu cầu checkout…'
                  : '✅  Hoàn thành ca & Check-out'))),
    ]);
  }
}
