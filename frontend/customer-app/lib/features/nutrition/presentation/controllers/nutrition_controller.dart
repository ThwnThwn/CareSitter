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
import '../models/nutrition_week_generation_result.dart';
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
  final resource =
      snapshot.resource?.id == request.resourceId ? snapshot.resource : null;
  return NutritionFlow(
      health: snapshot.health?.revision == request.healthRevision
          ? snapshot.health
          : null,
      resource: resource,
      loading: request.loading,
      restoringPlan: request.restoringPlan,
      error: request.error,
      recommendationsEnabled: request.recommendationsEnabled,
      canAssess: NutritionAssessmentRules.canStart(
          loading: request.loading,
          restoringPlan: request.restoringPlan,
          resourceStatus: resource?.status,
          retryable: resource?.result.retryable ?? false,
          retryAllowed: resource?.result.decision.allows('retry') ?? false),
      selectedDate: request.selectedDate,
      dateLoading: request.dateLoading,
      dateError: request.dateError,
      weekProgress: request.weekProgress,
      planTargetDays: request.planTargetDays);
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
  int _dateRequestGeneration = 0;
  DateTime? _automaticRecommendationDate;
  bool _advancingAutomatically = false;
  NutritionFlowController(this.repository, this.id, this.user,
      {NutritionSnapshotStore? cache})
      : _cache = cache ?? NutritionSnapshotStore(),
        _ownsCache = cache == null,
        super(NutritionRequestState(beneficiaryId: id, loading: true)) {
    Future.microtask(() {
      if (mounted) load();
    });
  }
  NutritionFlow get view {
    final resource = _cache.state.resource;
    return NutritionFlow(
      health: _cache.state.health,
      resource: resource,
      loading: state.loading,
      restoringPlan: state.restoringPlan,
      error: state.error,
      recommendationsEnabled: state.recommendationsEnabled,
      canAssess: NutritionAssessmentRules.canStart(
          loading: state.loading,
          restoringPlan: state.restoringPlan,
          resourceStatus: resource?.status,
          retryable: resource?.result.retryable ?? false,
          retryAllowed: resource?.result.decision.allows('retry') ?? false),
      selectedDate: state.selectedDate,
      dateLoading: state.dateLoading,
      dateError: state.dateError,
      weekProgress: state.weekProgress,
      planTargetDays: state.planTargetDays,
    );
  }

  void _publish(NutritionFlow value) {
    if (!mounted || !_cache.mounted) return;
    _cache.replace(
        NutritionSnapshot(health: value.health, resource: value.resource));
    state = NutritionRequestState(
        beneficiaryId: id,
        healthRevision: value.health?.revision ?? 0,
        resourceId: value.resource?.id,
        loading: value.loading,
        restoringPlan: value.restoringPlan,
        error: value.error,
        recommendationsEnabled: value.recommendationsEnabled,
        selectedDate: state.selectedDate,
        dateLoading: state.dateLoading,
        dateError: state.dateError,
        weekProgress: state.weekProgress,
        planTargetDays: state.planTargetDays);
  }

  int get revision => view.health?.revision ?? 0;
  void _cancel() {
    _scope.cancel();
    _poller.stop();
  }

  bool _current(int generation) => mounted && _scope.current(generation);

  Future<void> load({bool restorePlan = true}) async {
    _automaticRecommendationDate = null;
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
      if (!restorePlan) {
        _actions.healthChanged();
        _publish(NutritionFlow(
            health: health,
            recommendationsEnabled: flags.recommendationsEnabled));
        return;
      }
      _publish(NutritionFlow(
          health: health,
          restoringPlan: true,
          recommendationsEnabled: flags.recommendationsEnabled));
      try {
        final plan = await _actions
            .latestPlan(_token)
            .timeout(NutritionActionsController.planLoadTimeout);
        if (!_current(generation)) return;
        _publish(NutritionFlow(
            health: health,
            resource: plan,
            recommendationsEnabled: flags.recommendationsEnabled));
      } catch (error) {
        if (!_current(generation)) return;
        if (error is TimeoutException) _cancel();
        _publish(NutritionFlow(
            health: health,
            error: error is TimeoutException
                ? 'Không tải kịp thực đơn đã lưu. Vui lòng thử lại.'
                : NutritionFailureModel(error).message,
            recommendationsEnabled: flags.recommendationsEnabled));
      }
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

  Future<void> saveHealthAndAssess(Map<String, dynamic> changes,
      {DateTime? plannedDate}) async {
    if (!mounted || view.loading || revision == 0) return;
    if (changes.isNotEmpty) {
      final saving = saveHealth(changes);
      final generation = _generation;
      await saving;
      if (!_current(generation) || view.error != null || view.health == null) {
        return;
      }
    }
    _automaticRecommendationDate = plannedDate;
    await assess();
    if (plannedDate != null) {
      await _advanceAutomaticRecommendation(_generation);
    }
  }

  Future<void> _advanceAutomaticRecommendation(int generation) async {
    if (_advancingAutomatically ||
        !_current(generation) ||
        _automaticRecommendationDate == null ||
        view.error != null) {
      return;
    }
    final resource = view.resource;
    if (resource == null || resource.healthRevision != revision) {
      return;
    }
    if (NutritionAssessmentRules.pending(resource.status)) {
      return;
    }
    if (resource.status != 'awaiting_confirmation' ||
        resource.payload['parserSchemaVersion'] != null ||
        !resource.result.decision.allows('confirm') ||
        !view.recommendationsEnabled) {
      _automaticRecommendationDate = null;
      return;
    }
    _advancingAutomatically = true;
    final date = _automaticRecommendationDate!;
    try {
      await confirm();
      if (!_current(generation) || view.error != null) {
        return;
      }
      final confirmed = view.resource;
      if (confirmed?.status != 'confirmed' ||
          confirmed?.result.decision.allows('recommend') != true) {
        return;
      }
      await recommend(plannedDate: date);
    } finally {
      _automaticRecommendationDate = null;
      _advancingAutomatically = false;
    }
  }

  Future<void> assess({bool retryFailed = false}) async {
    if (!mounted || !view.canAssess) return;
    if (view.resource?.status == 'stale') {
      await reassess();
      return;
    }
    final retryOf = retryFailed || view.resource?.status == 'failed'
        ? view.resource?.id
        : null;
    _cancel();
    final generation = _generation;
    await _withResource(
        () => _actions.assess(revision, _token, retryOf: retryOf));
    if (!_current(generation)) return;
    final r = view.resource;
    if (r != null && NutritionAssessmentRules.pending(r.status)) {
      _schedule(r.id, _generation);
    }
  }

  Future<void> confirm() => _withResource(
      () => _actions.confirm(view.resource!.id, revision, _token));
  Future<void> recommend({required DateTime plannedDate}) => _withResource(() =>
      _actions.recommend(view.resource!.id, revision, _token,
          plannedDate: plannedDate));

  Future<bool> recommendForDateUsingConfirmedHealth(
      DateTime plannedDate) async {
    if (!mounted || view.loading || view.restoringPlan || revision == 0) {
      return false;
    }
    final current = view.resource;
    if (current == null || current.healthRevision != revision) return false;
    final assessmentId = current.status == 'confirmed'
        ? current.id
        : current.result.assessmentId;
    if (assessmentId == null || assessmentId.isEmpty) return false;
    await _withResource(() => _actions.recommend(
          assessmentId,
          revision,
          _token,
          plannedDate: plannedDate,
        ));
    final result = view.resource;
    final resultDate = DateTime.tryParse(result?.result.plannedDate ?? '');
    return view.error == null &&
        result?.status == 'suggested' &&
        _sameDate(resultDate, _dateOnly(plannedDate));
  }

  Future<NutritionWeekGenerationResult> generateWeek(DateTime startDate,
      {int days = 7}) async {
    if (!const {3, 5, 7}.contains(days)) {
      return NutritionWeekGenerationResult(
          createdDays: 0,
          existingDays: 0,
          targetDays: days,
          error: 'Khoảng thời gian tạo thực đơn không hợp lệ.');
    }
    const unavailable =
        'Hãy lưu và kiểm tra hồ sơ dinh dưỡng trước khi tạo thực đơn tuần.';
    if (!mounted ||
        view.loading ||
        view.restoringPlan ||
        !view.recommendationsEnabled ||
        revision == 0) {
      return NutritionWeekGenerationResult(
          createdDays: 0,
          existingDays: 0,
          targetDays: days,
          error: unavailable,
          needsProfile: true);
    }
    final starting = view;
    final resource = starting.resource;
    final assessmentId = resource?.status == 'confirmed'
        ? resource?.id
        : resource?.result.assessmentId;
    if (resource == null ||
        resource.status == 'stale' ||
        resource.healthRevision != revision ||
        assessmentId == null ||
        assessmentId.isEmpty) {
      return NutritionWeekGenerationResult(
          createdDays: 0,
          existingDays: 0,
          targetDays: days,
          error: unavailable,
          needsProfile: true);
    }

    _automaticRecommendationDate = null;
    _cancel();
    final generation = _generation;
    final healthRevision = revision;
    final firstDate = _dateOnly(startDate);
    var created = 0;
    var existing = 0;
    String? failure;
    NutritionFailureModel? requestFailure;
    var stale = false;
    NutritionResourceModel? firstPlan;
    final usedIds = <String>{};
    final usedNames = <String>{};
    _setWeekProgress(0, targetDays: days);
    _publish(NutritionFlow(
        health: starting.health,
        resource: resource,
        loading: true,
        recommendationsEnabled: starting.recommendationsEnabled));
    try {
      final savedPlans = await _actions.plans(_token, weekStart: firstDate);
      if (!_current(generation)) {
        return NutritionWeekGenerationResult(
            createdDays: created, existingDays: existing, targetDays: days);
      }
      final byDate = <String, NutritionResourceModel>{};
      final lastDate =
          DateTime(firstDate.year, firstDate.month, firstDate.day + days - 1);
      for (final plan in savedPlans) {
        final date = DateTime.tryParse(plan.plannedDate);
        if (plan.id.isEmpty ||
            date == null ||
            date.isBefore(firstDate) ||
            date.isAfter(lastDate) ||
            byDate.containsKey(plan.plannedDate)) {
          continue;
        }
        final stored = await _actions.openPlan(plan.id, _token);
        if (!_current(generation)) break;
        final signatures = _menuSignatures(stored);
        stale =
            stored.status == 'stale' || stored.healthRevision != healthRevision;
        if (stored.status != 'saved' ||
            stale ||
            !_sameDate(
                DateTime.tryParse(stored.result.plannedDate ?? ''), date) ||
            signatures == null ||
            usedIds.contains(signatures.$1) ||
            usedNames.contains(signatures.$2)) {
          failure =
              'Thực đơn ngày ${date.day}/${date.month} cần được kiểm tra lại.';
          break;
        }
        byDate[plan.plannedDate] = stored;
        usedIds.add(signatures.$1);
        usedNames.add(signatures.$2);
      }
      existing = byDate.length;
      _setWeekProgress(existing, targetDays: days);
      for (var day = 0; day < days && failure == null; day++) {
        if (!_current(generation)) break;
        final date =
            DateTime(firstDate.year, firstDate.month, firstDate.day + day);
        final dateKey = _apiDate(date);
        final previous = byDate[dateKey];
        NutritionResourceModel plan;
        if (previous != null) {
          plan = previous;
        } else {
          final suggestion = await _actions.recommend(
              assessmentId, healthRevision, _token,
              plannedDate: date);
          if (!_current(generation)) break;
          stale = suggestion.status == 'stale' ||
              suggestion.healthRevision != healthRevision;
          if (suggestion.status != 'suggested' ||
              stale ||
              !_sameDate(DateTime.tryParse(suggestion.result.plannedDate ?? ''),
                  date) ||
              !suggestion.result.decision.allows('save')) {
            failure =
                'Chưa tìm được thực đơn phù hợp cho ngày ${date.day}/${date.month}.';
            break;
          }
          final signatures = _menuSignatures(suggestion);
          if (signatures == null ||
              usedIds.contains(signatures.$1) ||
              usedNames.contains(signatures.$2)) {
            failure =
                'Chưa tìm được thực đơn khác các ngày trước cho ngày ${date.day}/${date.month}.';
            break;
          }
          plan = await _actions.save(suggestion.id, healthRevision, _token,
              plannedDate: date);
          if (!_current(generation)) break;
          stale =
              plan.status == 'stale' || plan.healthRevision != healthRevision;
          if (plan.status != 'saved' ||
              stale ||
              !_sameDate(
                  DateTime.tryParse(plan.result.plannedDate ?? ''), date)) {
            failure = 'Chưa lưu được thực đơn ngày ${date.day}/${date.month}.';
            break;
          }
        }
        final signatures = _menuSignatures(plan);
        if (signatures == null ||
            (previous == null &&
                (usedIds.contains(signatures.$1) ||
                    usedNames.contains(signatures.$2)))) {
          failure =
              'Thực đơn ngày ${date.day}/${date.month} trùng hoặc thiếu bữa.';
          break;
        }
        usedIds.add(signatures.$1);
        usedNames.add(signatures.$2);
        firstPlan ??= plan;
        if (previous == null) created++;
        _setWeekProgress(created + existing, targetDays: days);
      }
    } catch (error) {
      if (_current(generation)) {
        requestFailure = NutritionFailureModel(error);
        failure = requestFailure.message;
      }
    } finally {
      if (_current(generation)) {
        _setWeekProgress(null);
        final denied = requestFailure?.denied == true;
        final changed = stale || requestFailure?.stale == true;
        final result = firstPlan ?? resource;
        _publish(NutritionFlow(
            health: denied ? null : starting.health,
            resource: denied
                ? null
                : changed
                    ? result.withStatus('stale')
                    : result,
            error: failure,
            recommendationsEnabled: starting.recommendationsEnabled));
      }
    }
    return NutritionWeekGenerationResult(
        createdDays: created,
        existingDays: existing,
        targetDays: days,
        error: failure);
  }

  (String, String)? _menuSignatures(NutritionResourceModel resource) {
    final meals = resource.result.meals.toList()
      ..sort((a, b) => a.mealType.compareTo(b.mealType));
    if (meals.length != 3 ||
        !meals
            .map((meal) => meal.mealType)
            .toSet()
            .containsAll(const {'breakfast', 'lunch', 'dinner'}) ||
        meals.any((meal) =>
            meal.recipeVersionId.isEmpty || meal.name.trim().isEmpty)) {
      return null;
    }
    return (
      meals.map((meal) => '${meal.mealType}:${meal.recipeVersionId}').join('|'),
      meals
          .map((meal) => '${meal.mealType}:${meal.name.trim().toLowerCase()}')
          .join('|'),
    );
  }

  String _apiDate(DateTime date) => date.toIso8601String().split('T').first;

  Future<void> reassess() async {
    if (!mounted || view.loading || view.restoringPlan) return;
    final refresh = load(restorePlan: false);
    final generation = _generation;
    await refresh;
    if (!_current(generation) || view.health == null || view.error != null) {
      return;
    }
    await assess();
  }

  Future<void> save() =>
      _withResource(() => _actions.save(view.resource!.id, revision, _token));
  Future<void> replace(String recipeVersionId, String mealType) =>
      _withResource(() => _actions.replace(
          view.resource!.id, recipeVersionId, mealType, revision, _token));
  Future<List<RecipeOptionModel>?> options(String mealType) =>
      _list(() => _actions.options(view.resource!.id, mealType, _token));
  Future<List<MealPlanSummaryModel>?> plans({DateTime? weekStart}) =>
      _list(() => _actions.plans(_token, weekStart: weekStart));

  void selectDate(DateTime date) {
    if (!mounted || state.dateLoading) return;
    _automaticRecommendationDate = null;
    _setDateState(selectedDate: _dateOnly(date), clearError: true);
  }

  void adoptResourceDate() {
    final date = DateTime.tryParse(view.resource?.result.plannedDate ?? '');
    if (date == null) return;
    _dateRequestGeneration++;
    _setDateState(
        selectedDate: _dateOnly(date), loading: false, clearError: true);
  }

  Future<bool> openPlanForDate(DateTime date) async {
    if (!mounted || state.dateLoading) return false;
    final requestGeneration = ++_dateRequestGeneration;
    final selectedDate = _dateOnly(date);
    _setDateState(selectedDate: selectedDate, loading: true, clearError: true);
    try {
      final currentDate =
          DateTime.tryParse(view.resource?.result.plannedDate ?? '');
      if (_sameDate(currentDate, selectedDate)) return true;
      final availablePlans = await plans(weekStart: selectedDate);
      if (!_currentDateRequest(requestGeneration)) return false;
      if (availablePlans == null) {
        _setDateState(dateError: view.error ?? _dateLoadFailure);
        return false;
      }
      for (final plan in availablePlans) {
        if (!_sameDate(DateTime.tryParse(plan.plannedDate), selectedDate) ||
            plan.id.isEmpty) {
          continue;
        }
        await openPlan(plan.id);
        if (!_currentDateRequest(requestGeneration)) return false;
        final opened = view.resource?.id == plan.id;
        _setDateState(
            dateError: opened ? null : view.error ?? _dateLoadFailure,
            clearError: opened);
        return opened;
      }
      return false;
    } catch (_) {
      if (_currentDateRequest(requestGeneration)) {
        _setDateState(dateError: _dateLoadFailure);
      }
      return false;
    } finally {
      if (_currentDateRequest(requestGeneration)) {
        _setDateState(loading: false);
      }
    }
  }

  bool _currentDateRequest(int generation) =>
      mounted && generation == _dateRequestGeneration;

  void _setDateState({
    DateTime? selectedDate,
    bool? loading,
    String? dateError,
    bool clearError = false,
  }) {
    if (!mounted) return;
    state = NutritionRequestState(
        beneficiaryId: state.beneficiaryId,
        healthRevision: state.healthRevision,
        resourceId: state.resourceId,
        loading: state.loading,
        restoringPlan: state.restoringPlan,
        error: state.error,
        recommendationsEnabled: state.recommendationsEnabled,
        selectedDate: selectedDate ?? state.selectedDate,
        dateLoading: loading ?? state.dateLoading,
        dateError: clearError ? null : dateError ?? state.dateError,
        weekProgress: state.weekProgress,
        planTargetDays: state.planTargetDays);
  }

  void _setWeekProgress(int? progress, {int? targetDays}) {
    if (!mounted) return;
    state = NutritionRequestState(
        beneficiaryId: state.beneficiaryId,
        healthRevision: state.healthRevision,
        resourceId: state.resourceId,
        loading: state.loading,
        restoringPlan: state.restoringPlan,
        error: state.error,
        recommendationsEnabled: state.recommendationsEnabled,
        selectedDate: state.selectedDate,
        dateLoading: state.dateLoading,
        dateError: state.dateError,
        weekProgress: progress,
        planTargetDays:
            progress == null ? null : targetDays ?? state.planTargetDays);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDate(DateTime? first, DateTime second) =>
      first != null &&
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static const _dateLoadFailure =
      'Chưa tải được thực đơn cho ngày đã chọn. Vui lòng thử lại.';

  Future<void> openPlan(String planId) async {
    if (!mounted || view.loading || view.restoringPlan) return;
    _automaticRecommendationDate = null;
    // A result from the previous assessment must not replace this saved plan.
    _cancel();
    final generation = _generation;
    await _withResource(() => _actions.openPlan(planId, _token));
    if (!_current(generation)) return;
    final resource = view.resource;
    if (resource != null && NutritionAssessmentRules.pending(resource.status)) {
      _schedule(resource.id, generation);
    }
  }

  Future<List<T>?> _list<T>(Future<List<T>> Function() action) async {
    if (!mounted || view.loading || revision == 0) return null;
    final generation = _generation;
    try {
      final results = await action();
      if (!_current(generation)) return null;
      if (view.error != null) {
        _publish(NutritionFlow(
            health: view.health,
            resource: view.resource,
            recommendationsEnabled: view.recommendationsEnabled));
      }
      return results;
    } catch (e) {
      if (_current(generation)) {
        final failure = NutritionFailureModel(e);
        _publish(NutritionFlow(
            health: failure.denied ? null : view.health,
            resource: failure.denied ? null : view.resource,
            error: failure.message,
            recommendationsEnabled: view.recommendationsEnabled));
      }
      return null;
    }
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
        publish: (resource) {
          _publish(NutritionFlow(
              health: view.health,
              resource: resource,
              recommendationsEnabled: view.recommendationsEnabled));
          if (!NutritionAssessmentRules.pending(resource.status)) {
            unawaited(_advanceAutomaticRecommendation(generation));
          }
        },
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
    if (view.health == null || view.loading) {
      load();
      return;
    }
    if (r != null &&
        r.id.isNotEmpty &&
        NutritionAssessmentRules.pending(r.status)) {
      _schedule(r.id, _generation);
    }
  }

  void suspend() {
    _automaticRecommendationDate = null;
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
