import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/shifts/data/models/care_task_model.dart';
import 'package:caregiver_app/features/shifts/data/repositories/shift_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shiftDetailTasksProvider =
    FutureProvider.autoDispose.family<List<CareTaskModel>, String>((ref, id) {
  final session = ref.watch(authStateProvider.select((state) =>
      (state.valueOrNull?.userId, state.valueOrNull?.isAuthenticated)));
  if (session.$2 != true) return Future.value(const <CareTaskModel>[]);
  return ref.read(shiftRepositoryProvider).loadCareTasks(id);
});
