import 'nutrition_request_state.dart';
import 'nutrition_snapshot.dart';
import 'nutrition_snapshot_store.dart';
import 'nutrition_session_controller.dart';
import '../models/nutrition_flow_model.dart';
import '../../domain/nutrition_assessment_rules.dart';
import '../../data/models/nutrition_resource_model.dart';
import '../../data/models/recipe_option_model.dart';
import '../../data/models/meal_plan_summary_model.dart';
import '../models/nutrition_failure_model.dart';
import 'nutrition_operation_scope.dart';
import 'nutrition_assessment_poller.dart';
import 'nutrition_actions_controller.dart';
export 'nutrition_session_controller.dart';
export '../models/nutrition_flow_model.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../data/repositories/nutrition_repository.dart';

final nutritionControllerProvider = StateNotifierProvider.autoDispose
    .family<NutritionFlowController, NutritionRequestState, String>((ref, id) {
  ref.watch(nutritionSessionProvider);
  final user =
      ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
  final cache = ref.watch(nutritionSnapshotProvider(id).notifier);
  return NutritionFlowController(
      ref.read(nutritionRepositoryProvider), id, user,
      cache: cache);
});
final nutritionFlowProvider =
    Provider.autoDispose.family<NutritionFlow, String>((ref, id) {
  final request = ref.watch(nutritionControllerProvider(id));
  final snapshot = ref.watch(nutritionSnapshotProvider(id));
  return NutritionFlow(
      health: snapshot.health?.revision == request.healthRevision
          ? snapshot.health
          : null,
      resource: snapshot.resource?.id == request.resourceId
          ? snapshot.resource
          : null,
      loading: request.loading,
      error: request.error,
      recommendationsEnabled: request.recommendationsEnabled);
});

class NutritionFlowController extends StateNotifier<NutritionRequestState> {
  final NutritionRepository repository;
  final String id;
  final String? user;
  final _scope = NutritionOperationScope();
  final _poller = NutritionAssessmentPoller();
  late final _actions = NutritionActionsController(repository, id);
  ApiCancellation get _token => _scope.token;
  int get _generation => _scope.generation;
  final NutritionSnapshotStore _cache;
  final bool _ownsCache;
  NutritionFlowController(this.repository, this.id, this.user,
      {NutritionSnapshotStore? cache})
      : _cache = cache ?? NutritionSnapshotStore(),
        _ownsCache = cache == null,
        super(NutritionRequestState(beneficiaryId: id, loading: true)) {
    Future.microtask(() {
      if (mounted) load();
    });
  }
  NutritionFlow get view => NutritionFlow(
      health: _cache.state.health,
      resource: _cache.state.resource,
      loading: state.loading,
      error: state.error,
      recommendationsEnabled: state.recommendationsEnabled);
  void _publish(NutritionFlow value) {
    if (!mounted || !_cache.mounted) return;
    _cache.replace(
        NutritionSnapshot(health: value.health, resource: value.resource));
    state = NutritionRequestState(
        beneficiaryId: id,
        healthRevision: value.health?.revision ?? 0,
        resourceId: value.resource?.id,
        loading: value.loading,
        error: value.error,
        recommendationsEnabled: value.recommendationsEnabled);
  }

  int get revision => view.health?.revision ?? 0;
  void _cancel() {
    _scope.cancel();
    _poller.stop();
  }

  bool _current(int generation) => mounted && _scope.current(generation);

  Future<void> load() async {
    _cancel();
    final generation = _generation;
    _publish(const NutritionFlow(loading: true));
    try {
      if (user == null) throw StateError('Vui lòng đăng nhập lại.');
      if (!repository.isConfigured) {
        throw StateError('Dịch vụ thực đơn chưa được cấu hình.');
      }
      final flags = await repository.capabilities(_token);
      if (!_current(generation)) return;
      if (!flags.enabled || !flags.assessmentsEnabled) {
        throw StateError('Tính năng thực đơn chưa được mở.');
      }
      final health = await repository.health(id, _token);
      if (!_current(generation)) return;
      _publish(NutritionFlow(
          health: health,
          recommendationsEnabled: flags.recommendationsEnabled));
    } catch (e) {
      if (_current(generation)) {
        _publish(NutritionFlow(error: NutritionFailureModel(e).message));
      }
    }
  }

  Future<void> saveHealth(Map<String, dynamic> changes) async {
    if (!mounted || view.loading || revision == 0) return;
    _cancel();
    final generation = _generation;
    await _run(() async {
      final health = await repository.patch(id, revision, changes, _token);
      return NutritionFlow(
          health: health, recommendationsEnabled: view.recommendationsEnabled);
    });
    if (_current(generation) && view.error == null) _actions.healthChanged();
  }

  Future<void> assess({bool retryFailed = false}) async {
    if (!mounted || view.loading) return;
    _cancel();
    final generation = _generation;
    await _withResource(
        () => _actions.assess(revision, _token, retryFailed: retryFailed));
    if (!_current(generation)) return;
    final r = view.resource;
    if (r != null && NutritionAssessmentRules.pending(r.status)) {
      _schedule(r.id, _generation);
    }
  }

  Future<void> confirm() => _withResource(
      () => _actions.confirm(view.resource!.id, revision, _token));
  Future<void> recommend() => _withResource(
      () => _actions.recommend(view.resource!.id, revision, _token));
  Future<void> save() =>
      _withResource(() => _actions.save(view.resource!.id, revision, _token));
  Future<void> replace(String recipeVersionId, String mealType) =>
      _withResource(() => _actions.replace(
          view.resource!.id, recipeVersionId, mealType, revision, _token));
  Future<List<RecipeOptionModel>?> options(String mealType) =>
      _list(() => _actions.options(view.resource!.id, mealType, _token));
  Future<List<MealPlanSummaryModel>?> plans() =>
      _list(() => _actions.plans(_token));
  Future<void> openPlan(String planId) =>
      _withResource(() => _actions.openPlan(planId, _token));
  Future<List<T>?> _list<T>(Future<List<T>> Function() action) async {
    final generation = _generation;
    List<T>? results;
    await _run(() async {
      results = await action();
      return NutritionFlow(
          health: view.health,
          resource: view.resource,
          recommendationsEnabled: view.recommendationsEnabled);
    });
    return _current(generation) && view.error == null ? results : null;
  }

  Future<void> _withResource(
          Future<NutritionResourceModel> Function() action) =>
      _run(() async {
        final resource = await action();
        return NutritionFlow(
            health: view.health,
            resource: resource,
            recommendationsEnabled: view.recommendationsEnabled);
      });

  Future<void> _run(Future<NutritionFlow> Function() action) async {
    if (!mounted || view.loading || revision == 0) return;
    final generation = _generation;
    final previous = view;
    _publish(NutritionFlow(
        health: previous.health,
        resource: previous.resource,
        loading: true,
        recommendationsEnabled: previous.recommendationsEnabled));
    try {
      final next = await action();
      if (_current(generation)) _publish(next);
    } catch (e) {
      if (_current(generation)) {
        final failure = NutritionFailureModel(e);
        final denied = failure.denied, changed = failure.stale;
        _publish(NutritionFlow(
            health: denied ? null : previous.health,
            resource: denied
                ? null
                : changed && previous.resource != null
                    ? previous.resource!.withStatus('stale')
                    : previous.resource,
            error: failure.message,
            recommendationsEnabled: previous.recommendationsEnabled));
      }
    }
  }

  void _schedule(String assessment, int generation) {
    final token = _token;
    _poller.start(
        active: () => _current(generation),
        read: () => _actions.readAssessment(assessment, token),
        publish: (resource) => _publish(NutritionFlow(
            health: view.health,
            resource: resource,
            recommendationsEnabled: view.recommendationsEnabled)),
        timedOut: (resource) => _publish(NutritionFlow(
            health: view.health,
            resource: resource,
            error: 'Phân tích đang chờ xử lý. Vui lòng kiểm tra lại sau.',
            recommendationsEnabled: view.recommendationsEnabled)),
        failed: (error) {
          final failure = NutritionFailureModel(error);
          _publish(NutritionFlow(
              health: failure.denied ? null : view.health,
              resource: failure.denied ? null : view.resource,
              error: failure.message,
              recommendationsEnabled: view.recommendationsEnabled));
        });
  }

  void resume() {
    if (!mounted) return;
    final r = view.resource;
    if (r == null) {
      load();
      return;
    }
    if (r.id.isNotEmpty && NutritionAssessmentRules.pending(r.status)) {
      _schedule(r.id, _generation);
    } else {
      load();
    }
  }

  void suspend() {
    _cancel();
  }

  @override
  void dispose() {
    _scope.dispose();
    _poller.stop();
    if (_ownsCache) _cache.dispose();
    super.dispose();
  }
}
