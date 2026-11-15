import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../data/models/booking_payment_summary_model.dart';
import '../../data/repositories/booking_repository.dart';

final bookingPaymentSummaryProvider = FutureProvider.autoDispose
    .family<BookingPaymentSummaryModel, String>((ref, bookingId) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  return ref.read(bookingRepositoryProvider).getPaymentSummary(bookingId);
});
