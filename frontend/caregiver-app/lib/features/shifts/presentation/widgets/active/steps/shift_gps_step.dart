import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_action_feedback.dart';

class ShiftGpsStep extends ConsumerWidget {
  const ShiftGpsStep({super.key, required this.booking});
  final ShiftModel booking;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(shiftActiveProvider(booking.id)
        .select((s) => s.busy.contains('checkin')));
    return Column(children: [
      const Icon(Icons.my_location_rounded, size: 40),
      const SizedBox(height: AppSpacing.md),
      Text('Xác nhận vị trí GPS',
          style: Theme.of(context).textTheme.titleMedium),
      Text(booking.address),
      const SizedBox(height: AppSpacing.sm),
      const Text(
          'Vị trí hiện tại sẽ được máy chủ xác thực\ntrong phạm vi 50m của địa chỉ khách hàng.',
          textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.md),
      ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(busy ? 'Đang xác thực GPS...' : 'Xác nhận vị trí'),
          onPressed: busy
              ? null
              : () async {
                  final result = await ref
                      .read(shiftActiveProvider(booking.id).notifier)
                      .checkIn();
                  if (context.mounted) showShiftActionResult(context, result);
                }),
    ]);
  }
}
