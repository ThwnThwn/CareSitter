import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../data/models/booking_timeline_event_model.dart';
import '../../data/repositories/booking_timeline_repository.dart';

final bookingTimelineProvider = FutureProvider.autoDispose
    .family<List<BookingTimelineEventModel>, String>((ref, bookingId) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(bookingTimelineRepositoryProvider).load(bookingId);
});
