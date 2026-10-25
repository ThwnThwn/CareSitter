import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/utils/date_formatter.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_selectors.dart';
import 'package:caregiver_app/features/shifts/presentation/models/shift_display_model.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_action_feedback.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_note_field.dart';

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

  void _showPendingMessage(BuildContext context, WidgetRef ref) {
    final summary = ref.read(activeShiftSummaryProvider(booking.id));
    final required = booking.tasks.where((task) => task.isRequired);
    final pendingRequired = required.where((task) => !task.isResolved).length;
    final message = pendingRequired > 0
        ? 'Còn $pendingRequired công việc bắt buộc. Hãy hoàn thành và thêm ảnh minh chứng khi được yêu cầu.'
        : 'Còn ${summary.pending} công việc cần hoàn thành hoặc ghi lý do bỏ qua.';
    AppToast.error(context, message, title: 'Chưa thể kết thúc ca');
  }

  void _showNote(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.section),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShiftNoteField(
                    bookingId: booking.id,
                    enabled: true,
                  ),
                  const SizedBox(height: AppSpacing.compact),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Xong'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCheckout = ref.watch(
      activeShiftSummaryProvider(booking.id)
          .select((summary) => summary.canCheckout),
    );
    final busy = ref.watch(
      shiftActiveProvider(booking.id).select(
        (state) => state.busy.contains('checkout'),
      ),
    );
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.compact),
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : canCheckout
                          ? () => _submit(context, ref)
                          : () => _showPendingMessage(context, ref),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded, size: 18),
                  label: Text(
                    busy
                        ? 'Đang gửi yêu cầu check-out…'
                        : 'Kết thúc ca làm việc (Check-out)',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _FooterActions(
                onNote: () => _showNote(context),
                onHelp: () => context.push('/settings/support/chat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({required this.onNote, required this.onHelp});

  final VoidCallback onNote;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final note = _FooterButton(
      icon: Icons.edit_note_rounded,
      label: 'Ghi chú ca',
      onPressed: onNote,
    );
    final help = _FooterButton(
      icon: Icons.support_agent_rounded,
      label: 'Trợ giúp nhanh',
      onPressed: onHelp,
    );
    if (largeText) return Column(children: [note, help]);
    return Row(
      children: [
        Expanded(child: note),
        const SizedBox(
          height: 24,
          child: VerticalDivider(width: 1, color: AppColors.border),
        ),
        Expanded(child: help),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: AppColors.textSecondary,
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      );
}
