import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import '../../data/models/shift_model.dart';
import 'shift_list_controller.dart';

final shiftDetailLoadProvider =
    FutureProvider.autoDispose.family<ShiftModel, String>((ref, id) {
  final session = ref.watch(authStateProvider.select((state) =>
      (state.valueOrNull?.userId, state.valueOrNull?.isAuthenticated)));
  if (session.$2 != true) {
    throw const AppApiException(
        message: 'Vui lòng đăng nhập lại.', statusCode: 401);
  }
  final cancellation = ApiCancellation();
  ref.onDispose(cancellation.cancel);
  return ref.read(shiftsProvider.notifier).loadDetail(id, cancellation);
});

final shiftByIdProvider =
    Provider.autoDispose.family<AsyncValue<ShiftModel>, String>((ref, id) {
  final cached = ref.watch(shiftsProvider
      .select((items) => items.where((item) => item.id == id).firstOrNull));
  return cached == null
      ? ref.watch(shiftDetailLoadProvider(id))
      : AsyncData(cached);
});
