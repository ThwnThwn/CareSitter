import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_session_scope.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import '../../data/models/booking_meals_model.dart';
import '../../data/repositories/booking_meals_repository.dart';

final bookingMealsProvider = AutoDisposeAsyncNotifierProvider.family<
    BookingMealsController,
    BookingMealsModel,
    String>(BookingMealsController.new);

class BookingMealsController
    extends AutoDisposeFamilyAsyncNotifier<BookingMealsModel, String> {
  late AuthSessionScope _session;

  @override
  Future<BookingMealsModel> build(String arg) async {
    final session = _session = AuthSessionScope.watch(ref);
    session.requireCurrent();
    return ref
        .read(bookingMealsRepositoryProvider)
        .load(arg, session.cancellation);
  }

  Future<bool> share(String planId) => _write((repository, session) async {
        await repository.share(arg, planId, session.cancellation);
      });
  Future<bool> revoke(String plannedDate) => _write((repository, session) =>
      repository.revoke(arg, plannedDate, session.cancellation));

  Future<bool> _write(
      Future<void> Function(BookingMealsRepository, AuthSessionScope)
          operation) async {
    final before = state.valueOrNull;
    final session = _session;
    if (before == null || state.isLoading || !session.isCurrent) return false;
    final repository = ref.read(bookingMealsRepositoryProvider);
    state = const AsyncLoading<BookingMealsModel>()
        .copyWithPrevious(AsyncData(before));
    var saved = false;
    try {
      await operation(repository, session);
      saved = true;
      if (!session.isCurrent) return false;
      final updated = await repository.load(arg, session.cancellation);
      if (!session.isCurrent) return false;
      state = AsyncData(updated);
    } catch (error, stack) {
      if (!session.isCurrent) return false;
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
