import 'package:caregiver_app/core/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';

class ShiftTimerChip extends ConsumerWidget {
  const ShiftTimerChip({super.key, required this.bookingId});
  final String bookingId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed =
        ref.watch(shiftActiveProvider(bookingId).select((s) => s.elapsed));
    return Chip(
        avatar: const Icon(Icons.timer_outlined, size: 14),
        label: Text(formatDuration(elapsed)));
  }
}
