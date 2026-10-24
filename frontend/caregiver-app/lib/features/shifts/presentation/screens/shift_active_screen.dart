import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_active_content.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_checkout_section.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_editor.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_timer_chip.dart';

class ShiftActiveScreen extends ConsumerWidget {
  const ShiftActiveScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(
      shiftsProvider.select(
        (list) => list.where((booking) => booking.id == id).firstOrNull,
      ),
    );
    final checkedIn =
        ref.watch(shiftActiveProvider(id).select((s) => s.checkedIn));
    final error = ref.watch(shiftActiveProvider(id).select((s) => s.error));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ca đang diễn ra',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const AppBackButton(fallbackRoute: '/shifts'),
        actions: [
          if (checkedIn) ShiftTimerChip(bookingId: id),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              tooltip: 'Báo cáo khẩn cấp',
              style: IconButton.styleFrom(
                minimumSize: const Size.square(44),
                backgroundColor: AppColors.errorLight,
                foregroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.compact),
                ),
              ),
              icon: const Icon(Icons.warning_amber_rounded, size: 20),
              onPressed: booking == null
                  ? null
                  : () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => ShiftTaskEditor(
                          bookingId: id,
                          mode: ShiftTaskEditorMode.incident,
                        ),
                      ),
            ),
          ),
        ],
      ),
      body: booking == null
          ? const Center(
              child: Text('Không tìm thấy thông tin ca làm việc này.'))
          : ShiftActiveContent(
              booking: booking,
              checkedIn: checkedIn,
              error: error,
              onRetry: () =>
                  ref.read(shiftActiveProvider(id).notifier).loadTasks(),
            ),
      bottomNavigationBar:
          booking != null && booking.status == 'in_progress' && checkedIn
              ? ShiftCheckoutSection(booking: booking)
              : null,
    );
  }
}
