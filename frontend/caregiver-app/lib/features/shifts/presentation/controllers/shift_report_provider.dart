import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';

typedef ShiftReport = ({ShiftModel booking, String note});

final shiftReportProvider =
    FutureProvider.autoDispose.family<ShiftReport?, String>((ref, id) async {
  final session = ref.watch(authStateProvider.select(
    (state) => (state.valueOrNull?.userId, state.valueOrNull?.isAuthenticated),
  ));
  if (session.$2 != true) {
    throw const AppApiException(
        message: 'Vui lòng đăng nhập lại.', statusCode: 401);
  }
  final token = ApiCancellation();
  ref.onDispose(token.cancel);
  final repository = ref.watch(shiftRepositoryProvider);
  final booking = await repository.loadShift(id, token: token);
  if (booking.status != 'checkout_pending_review' &&
      booking.status != 'completed') {
    return null;
  }
  final (tasks, note) = await (
    repository.loadCareTasks(id, token: token),
    repository.loadCheckoutNote(id, token: token),
  ).wait;
  return (booking: booking.copyWith(tasks: tasks), note: note);
});
