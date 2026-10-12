import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../data/nutrition_repository.dart';

final nutritionSessionProvider =
    NotifierProvider<NutritionSession, int>(NutritionSession.new);

class NutritionSession extends Notifier<int> {
  @override
  int build() {
    ref.listen(authStateProvider, (old, next) {
      if (old?.value?.userId != next.value?.userId ||
          old?.value?.isAuthenticated != next.value?.isAuthenticated) {
        state++;
      }
    });
    return 0;
  }
}

final nutritionFlowProvider = StateNotifierProvider.autoDispose
    .family<NutritionFlowController, NutritionFlow, String>((ref, id) {
  ref.watch(nutritionSessionProvider);
  final user = ref.watch(authStateProvider.select((s) => s.value?.userId));
  return NutritionFlowController(
      ref.read(nutritionRepositoryProvider), id, user);
});

class NutritionFlow {
  final Map<String, dynamic>? health, resource;
  final bool loading, recommendationsEnabled;
  final String? error;
  const NutritionFlow(
      {this.health,
      this.resource,
      this.loading = false,
      this.error,
      this.recommendationsEnabled = false});
}

class NutritionFlowController extends StateNotifier<NutritionFlow> {
  final NutritionRepository repository;
  final String id;
  final String? user;
  CancelToken _token = CancelToken();
  int _generation = 0;
  final Map<String, String> _keys = {};
  Timer? _poll;
  NutritionFlowController(this.repository, this.id, this.user)
      : super(const NutritionFlow(loading: true)) {
    load();
  }
  int get revision => (state.health?['revision'] as num?)?.toInt() ?? 0;
  void _cancel() {
    _generation++;
    _token.cancel();
    _token = CancelToken();
    _poll?.cancel();
  }

  bool _current(int generation) => mounted && generation == _generation;

  Future<void> load() async {
    _cancel();
    final generation = _generation;
    state = const NutritionFlow(loading: true);
    try {
      if (user == null) throw StateError('Vui lòng đăng nhập lại.');
      if (!repository.isConfigured) {
        throw StateError('Dịch vụ thực đơn chưa được cấu hình.');
      }
      final flags = await repository.capabilities(_token);
      if (!_current(generation)) return;
      if (flags['enabled'] != true || flags['assessmentsEnabled'] != true) {
        throw StateError('Tính năng thực đơn chưa được mở.');
      }
      final health = await repository.health(id, _token);
      if (!_current(generation)) return;
      state = NutritionFlow(
          health: health,
          recommendationsEnabled: flags['recommendationsEnabled'] == true);
    } catch (e) {
      if (_current(generation)) state = NutritionFlow(error: _message(e));
    }
  }

  Future<void> saveHealth(Map<String, dynamic> changes) async {
    if (!mounted || state.loading || revision == 0) return;
    _cancel();
    await _run(() async {
      final health = await repository.patch(id, revision, changes, _token);
      return NutritionFlow(
          health: health, recommendationsEnabled: state.recommendationsEnabled);
    });
    if (mounted && state.error == null) _keys.clear();
  }

  Future<void> assess({bool retryFailed = false}) async {
    if (!mounted || state.loading) return;
    _cancel();
    final generation = _generation;
    if (retryFailed) {
      _keys.removeWhere((key, _) => key.startsWith('nutrition-assessments:'));
    }
    await _write('nutrition-assessments');
    if (!_current(generation)) return;
    final r = state.resource;
    if (r != null && (r['status'] == 'queued' || r['status'] == 'processing')) {
      _schedule(r['id'].toString(), _generation, 0);
    }
  }

  Future<void> confirm() =>
      _write('nutrition-assessments/${state.resource?['id']}/confirm');
  Future<void> recommend() => _write('meal-recommendations',
      extra: {'assessmentId': state.resource?['id']});
  Future<void> save() =>
      _write('meal-plans', extra: {'recommendationId': state.resource?['id']});
  Future<void> replace(String recipeVersionId, String mealType) =>
      _write('meal-recommendations/${state.resource?['id']}/replacements',
          extra: {'recipeVersionId': recipeVersionId, 'mealType': mealType});
  Future<List<Map<String, dynamic>>?> options(String mealType) => _list(
      'meal-recommendations/${state.resource?['id']}/replacement-options?mealType=$mealType');
  Future<List<Map<String, dynamic>>?> plans() => _list('meal-plans');
  Future<void> openPlan(String planId) => _run(() async {
        final r = await repository.read(id, 'meal-plans/$planId', _token);
        return NutritionFlow(
            health: state.health,
            resource: r,
            recommendationsEnabled: state.recommendationsEnabled);
      });
  Future<List<Map<String, dynamic>>?> _list(String route) async {
    final generation = _generation;
    List<Map<String, dynamic>>? results;
    await _run(() async {
      results = await repository.list(id, route, _token);
      return NutritionFlow(
          health: state.health,
          resource: state.resource,
          recommendationsEnabled: state.recommendationsEnabled);
    });
    return _current(generation) && state.error == null ? results : null;
  }

  Future<void> _write(String route, {Map<String, dynamic> extra = const {}}) =>
      _run(() async {
        final key = _keys.putIfAbsent(
            '$route:$revision:${jsonEncode(extra)}', () => const Uuid().v4());
        final r = await repository.write(
            id,
            route,
            {
              'expectedHealthRevision': revision,
              'idempotencyKey': key,
              ...extra
            },
            _token);
        return NutritionFlow(
            health: state.health,
            resource: r,
            recommendationsEnabled: state.recommendationsEnabled);
      });

  Future<void> _run(Future<NutritionFlow> Function() action) async {
    if (!mounted || state.loading || revision == 0) return;
    final generation = _generation;
    final previous = state;
    state = NutritionFlow(
        health: previous.health,
        resource: previous.resource,
        loading: true,
        recommendationsEnabled: previous.recommendationsEnabled);
    try {
      final next = await action();
      if (_current(generation)) state = next;
    } catch (e) {
      if (_current(generation)) {
        final denied = e is DioException &&
            [401, 403, 404].contains(e.response?.statusCode);
        final changed = e is DioException &&
            e.response?.statusCode == 409 &&
            e.response?.data is Map &&
            ['nutrition.profile_changed', 'nutrition.content_changed']
                .contains(e.response?.data['title']);
        state = NutritionFlow(
            health: denied ? null : previous.health,
            resource: denied
                ? null
                : changed && previous.resource != null
                    ? {...previous.resource!, 'status': 'stale'}
                    : previous.resource,
            error: _message(e),
            recommendationsEnabled: previous.recommendationsEnabled);
      }
    }
  }

  void _schedule(String assessment, int generation, int attempt) {
    _poll?.cancel();
    _poll = Timer(Duration(seconds: attempt < 3 ? 2 : 5), () async {
      if (!_current(generation)) return;
      try {
        final r = await repository.read(
            id, 'nutrition-assessments/$assessment', _token);
        if (!_current(generation)) return;
        state = NutritionFlow(
            health: state.health,
            resource: r,
            recommendationsEnabled: state.recommendationsEnabled);
        if (r['status'] == 'queued' || r['status'] == 'processing') {
          if (attempt < 60) {
            _schedule(assessment, generation, attempt + 1);
          } else {
            state = NutritionFlow(
                health: state.health,
                resource: r,
                error: 'Phân tích đang chờ xử lý. Vui lòng kiểm tra lại sau.',
                recommendationsEnabled: state.recommendationsEnabled);
          }
        }
      } catch (e) {
        if (_current(generation)) {
          final denied = e is DioException &&
              [401, 403, 404].contains(e.response?.statusCode);
          state = NutritionFlow(
              health: denied ? null : state.health,
              resource: denied ? null : state.resource,
              error: _message(e),
              recommendationsEnabled: state.recommendationsEnabled);
        }
      }
    });
  }

  void resume() {
    if (!mounted) return;
    final r = state.resource;
    if (r == null) {
      load();
      return;
    }
    if (r['id'] != null &&
        (r['status'] == 'queued' || r['status'] == 'processing')) {
      _schedule(r['id'].toString(), _generation, 0);
    } else {
      load();
    }
  }

  void suspend() {
    _cancel();
  }

  static String _message(Object e) {
    if (e is DioException) {
      if (e.response?.statusCode == 404) {
        return 'Hồ sơ hoặc nội dung không còn khả dụng.';
      }
      final body = e.response?.data;
      if (body is Map && body['detail'] is String) {
        return body['detail'] as String;
      }
      return 'Chưa kết nối được dịch vụ. Dữ liệu đã nhập vẫn được giữ.';
    }
    return e is StateError
        ? e.message.toString()
        : 'Chưa xử lý được yêu cầu. Vui lòng thử lại.';
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }
}
