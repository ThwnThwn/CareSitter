import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import '../../data/models/booking_meals_model.dart';
import '../../data/repositories/booking_meals_repository.dart';

final bookingMealsProvider = AutoDisposeAsyncNotifierProvider.family<
    BookingMealsController,
    BookingMealsModel,
    String>(BookingMealsController.new);

class BookingMealsController
    extends AutoDisposeFamilyAsyncNotifier<BookingMealsModel, String> {
  late ApiCancellation _token;
  late (String?, bool, int) _identity;
  final Map<String, String> _keys = {};

  @override
  Future<BookingMealsModel> build(String arg) async {
    final auth = ref.read(authStateProvider.notifier);
    _identity = ref.watch(authStateProvider.select((s) => (
          s.valueOrNull?.userId,
          s.valueOrNull?.isAuthenticated == true,
          auth.sessionGeneration,
        )));
    final token = _token = ApiCancellation();
    _keys.clear();
    ref.onDispose(token.cancel);
    if (!_identity.$2 || _identity.$1 == null) {
      throw StateError('Người chăm sóc cần đăng nhập.');
    }
    return ref.read(bookingMealsRepositoryProvider).load(arg, token: token);
  }

  Future<bool> record(
      {required String planId,
      required String recipeVersionId,
      required String mealType,
      required String outcome,
      String? note}) {
    final payload =
        jsonEncode([planId, recipeVersionId, mealType, outcome, note]);
    final key = _keys.putIfAbsent(payload, () => const Uuid().v4());
    return _write((repository, token) => repository.record(arg,
        planId: planId,
        recipeVersionId: recipeVersionId,
        mealType: mealType,
        outcome: outcome,
        note: note,
        idempotencyKey: key,
        token: token));
  }

  Future<bool> correct(
      {required String recordId,
      required String outcome,
      required String reason,
      required int expectedRevision,
      String? note}) {
    final payload = jsonEncode(
        ['correction', recordId, outcome, reason, expectedRevision, note]);
    final key = _keys.putIfAbsent(payload, () => const Uuid().v4());
    return _write((repository, token) => repository.correct(arg,
        recordId: recordId,
        outcome: outcome,
        reason: reason,
        note: note,
        expectedRevision: expectedRevision,
        idempotencyKey: key,
        token: token));
  }

  bool _isCurrent(ApiCancellation token, (String?, bool, int) identity) {
    if (token.isCancelled) return false;
    final auth = ref.read(authStateProvider).valueOrNull;
    return identity ==
        (
          auth?.userId,
          auth?.isAuthenticated == true,
          ref.read(authStateProvider.notifier).sessionGeneration,
        );
  }

  Future<bool> _write(
      Future<void> Function(BookingMealsRepository, ApiCancellation)
          operation) async {
    final before = state.valueOrNull;
    final token = _token;
    final identity = _identity;
    if (before == null || state.isLoading || !_isCurrent(token, identity)) {
      return false;
    }
    final repository = ref.read(bookingMealsRepositoryProvider);
    state = const AsyncLoading<BookingMealsModel>()
        .copyWithPrevious(AsyncData(before));
    var saved = false;
    try {
      await operation(repository, token);
      saved = true;
      if (!_isCurrent(token, identity)) return false;
      final updated = await repository.load(arg, token: token);
      if (!_isCurrent(token, identity)) return false;
      state = AsyncData(updated);
    } catch (error, stack) {
      if (!_isCurrent(token, identity)) return false;
      final problem = AsyncError<BookingMealsModel>(error, stack);
      final accessLost = error is AppApiException &&
          (error.statusCode == 401 || error.statusCode == 403);
      state = saved || accessLost
          ? problem
          : problem.copyWithPrevious(AsyncData(before));
    }
    return saved;
  }
}
