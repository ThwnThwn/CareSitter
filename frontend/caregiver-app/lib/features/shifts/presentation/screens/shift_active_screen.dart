import 'package:caregiver_app/features/shifts/presentation/controllers/shift_action_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_checkin_flow.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_checklist.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_checkout_section.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_note_field.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_editor.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_timer_chip.dart';

class ShiftActiveScreen extends ConsumerWidget {
  const ShiftActiveScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(
        shiftsProvider.select((list) => list.where((b) => b.id == id).firstOrNull));
    final checkedIn = ref.watch(shiftActiveProvider(id).select((s) => s.checkedIn));
    final error = ref.watch(shiftActiveProvider(id).select((s) => s.error));
    final user = ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
    final timerFitsBar = MediaQuery.sizeOf(context).width >= 360 &&
        MediaQuery.textScalerOf(context).scale(14) <= 21;
    return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Ca đang diễn ra'),
            leading: const AppBackButton(fallbackRoute: '/shifts'),
            actions: [
              if (checkedIn && timerFitsBar) ShiftTimerChip(bookingId: id),
              IconButton(
                  icon: const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error),
                  tooltip: 'Báo cáo sự cố',
                  onPressed: booking == null
                      ? null
                      : () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ShiftTaskEditor(
                              bookingId: id, mode: ShiftTaskEditorMode.incident))),
            ]),
        body: booking == null
            ? const Center(child: Text('Không tìm thấy thông tin ca làm việc này.'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.section),
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (checkedIn && !timerFitsBar)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: ShiftTimerChip(bookingId: id)),
                  if (error != null)
                    TextButton(
                        onPressed: () =>
                            ref.read(shiftActiveProvider(id).notifier).loadTasks(),
                        child: Text(error)),
                  if (checkedIn)
                    const ListTile(
                        leading:
                            Icon(Icons.verified_rounded, color: AppColors.success),
                        title: Text('Đã check-in • GPS đã được xác thực'))
                  else
                    ShiftCheckinFlow(booking: booking),
                  const SizedBox(height: AppSpacing.lg),
                  ShiftChecklist(booking: booking),
                  if (checkedIn) ...[
                    const SizedBox(height: AppSpacing.lg),
                    ShiftNoteField(
                        key: ValueKey('note-$id-$user'),
                        bookingId: id,
                        enabled: booking.canWorkChecklist),
                    const SizedBox(height: AppSpacing.lg),
                    ShiftCheckoutSection(booking: booking),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ])));
  }
}
