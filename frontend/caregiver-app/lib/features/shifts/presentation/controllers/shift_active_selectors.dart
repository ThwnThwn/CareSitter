import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/domain/shift_active_rules.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';

final activeShiftSummaryProvider =
    Provider.autoDispose.family((ref, String id) {
  final booking = ref.watch(shiftsProvider
      .select((list) => list.where((b) => b.id == id).firstOrNull));
  final tasks = booking?.tasks ?? [];
  return (
    total: tasks.length,
    completed: tasks.where((t) => t.isCompleted).length,
    pending: tasks.where((t) => t.status == 'PENDING').length,
    requiredSkipped: tasks.where((t) => t.isRequired && t.isSkipped).length,
    skipped: tasks.where((t) => t.isSkipped).length,
    canCheckout: booking != null &&
        ShiftActiveRules.canCheckout(booking.status, tasks.map((t) => t.status))
  );
});
