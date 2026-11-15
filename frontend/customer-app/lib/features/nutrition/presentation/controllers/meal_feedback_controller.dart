import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import '../../data/repositories/meal_feedback_repository.dart';
import '../../data/repositories/nutrition_repository.dart';
import 'meal_feedback_state.dart';

typedef MealFeedbackScope = ({String beneficiaryId, String planId});
final mealFeedbackProvider = AutoDisposeAsyncNotifierProvider.family<
    MealFeedbackController,
    MealFeedbackState,
    MealFeedbackScope>(MealFeedbackController.new);

class MealFeedbackController extends AutoDisposeFamilyAsyncNotifier<
    MealFeedbackState, MealFeedbackScope> {
  int _epoch = 0;
  bool _busy = false;
  final _keys = <String, String>{};
  late ApiCancellation _token;
  @override
  Future<MealFeedbackState> build(MealFeedbackScope arg) async {
    ref.watch(authStateProvider.select(
        (s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
    _epoch++;
    _busy = false;
    _keys.clear();
    final token = _token = ApiCancellation();
    ref.onDispose(() {
      _epoch++;
      token.cancel();
    });
    final nutrition = ref.read(nutritionRepositoryProvider);
    final feedback = ref.read(mealFeedbackRepositoryProvider);
    final plan = await nutrition.read(
        arg.beneficiaryId, 'meal-plans/${arg.planId}', token);
    if (token.isCancelled) throw StateError('Feedback scope ended.');
    return MealFeedbackState(
        plan, await feedback.load(arg.beneficiaryId, arg.planId, token));
  }

  Future<bool> submit(String recipeId, String feedback) {
    final key = _keys.putIfAbsent(
        jsonEncode([recipeId, feedback]), () => const Uuid().v4());
    return _write(() => ref
        .read(mealFeedbackRepositoryProvider)
        .submit(arg.beneficiaryId, arg.planId, recipeId, feedback, key));
  }

  Future<bool> review(String id, bool approve) {
    final revision = state.valueOrNull?.feedback.healthRevision;
    if (revision == null) return Future.value(false);
    return _write(() => ref
        .read(mealFeedbackRepositoryProvider)
        .review(arg.beneficiaryId, id, approve, revision));
  }

  Future<bool> _write(Future<void> Function() action) async {
    final before = state.valueOrNull;
    if (_busy || before == null) return false;
    final epoch = _epoch;
    _busy = true;
    state = const AsyncLoading<MealFeedbackState>().copyWithPrevious(state);
    try {
      await action();
      if (epoch != _epoch) return false;
      final feedback = await ref
          .read(mealFeedbackRepositoryProvider)
          .load(arg.beneficiaryId, arg.planId, _token);
      if (epoch != _epoch) return false;
      state = AsyncData(MealFeedbackState(before.plan, feedback));
      return true;
    } catch (error, stack) {
      if (epoch == _epoch) {
        state = AsyncError<MealFeedbackState>(error, stack)
            .copyWithPrevious(AsyncData(before));
      }
      return false;
    } finally {
      if (epoch == _epoch) _busy = false;
    }
  }
}
