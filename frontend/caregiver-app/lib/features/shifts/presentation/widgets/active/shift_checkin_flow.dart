import 'package:caregiver_app/features/shifts/presentation/controllers/shift_action_policy.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/steps/shift_selfie_step.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/steps/shift_gps_step.dart';

class ShiftCheckinFlow extends ConsumerWidget {
  const ShiftCheckinFlow({super.key, required this.booking});
  final ShiftModel booking;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(shiftActiveProvider(booking.id).select((s) => s.step));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(children: [
              Text('Check-in ca làm việc',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.compact),
              const Text('Selfie  →  GPS  →  Xác nhận'),
              const SizedBox(height: AppSpacing.md),
              AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: switch (step) {
                    1 =>
                      ShiftSelfieStep(key: const ValueKey(1), bookingId: booking.id),
                    2 => ShiftGpsStep(key: const ValueKey(2), booking: booking),
                    3 => const Text('Check-in thành công!'),
                    _ => Column(children: [
                        Text(booking.address),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                            onPressed: booking.canCheckIn
                                ? ref
                                    .read(shiftActiveProvider(booking.id).notifier)
                                    .startCheckIn
                                : null,
                            child: const Text('Bắt đầu check-in'))
                      ]),
                  }),
            ])));
  }
}
