import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/home/domain/home_shift_rules.dart';

final homeClockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  ref.watch(authStateProvider.select(
      (session) => (session.value?.userId, session.value?.isAuthenticated)));
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final homeShiftsProvider = Provider.autoDispose((ref) {
  final shifts = ref.watch(shiftsProvider);
  final now = ref.watch(homeClockProvider).value ?? DateTime.now();
  final today = shifts
      .where((s) => HomeShiftRules.isToday(s.status, s.scheduledStart, now))
      .toList();
  final offers = shifts
      .where((s) => HomeShiftRules.isOpenOffer(
          s.status, s.offerId, s.offerExpiresAt, now))
      .toList()
    ..sort((a, b) {
      final startOrder = (a.scheduledStart ?? DateTime.utc(9999))
          .compareTo(b.scheduledStart ?? DateTime.utc(9999));
      return startOrder != 0
          ? startOrder
          : (a.offerExpiresAt ?? DateTime.utc(9999))
              .compareTo(b.offerExpiresAt ?? DateTime.utc(9999));
    });
  final scheduled = shifts
      .where((s) => HomeShiftRules.isScheduledOrActive(s.status))
      .toList();
  return (today: today, offers: offers, scheduled: scheduled);
});

String? turnaroundWarning(ShiftModel offer, List<ShiftModel> shifts) {
  for (final shift in shifts) {
    if (HomeShiftRules.isTightTurnaround(offer.scheduledStart,
        offer.scheduledEnd, shift.scheduledStart, shift.scheduledEnd)) {
      return 'Ca này cách ca “${shift.serviceName}” chưa đến 30 phút. Hãy kiểm tra thời gian di chuyển trước khi nhận.';
    }
  }
  return null;
}
