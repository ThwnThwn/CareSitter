import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';

const nutritionBaseUrl = String.fromEnvironment('NUTRITION_BASE_URL');
final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) =>
    NutritionRepository(ref.read(dioClientProvider),
        DioClient(ref, baseUrl: nutritionBaseUrl)));
final nutritionEntryProvider = FutureProvider.autoDispose<bool>((ref) async {
  final session = ref.watch(authStateProvider
      .select((s) => (s.value?.userId, s.value?.isAuthenticated)));
  if (session.$2 != true) return false;
  if (nutritionBaseUrl.isEmpty) return false;
  final token = CancelToken();
  ref.onDispose(token.cancel);
  try {
    return (await ref
            .read(nutritionRepositoryProvider)
            .capabilities(token))['enabled'] ==
        true;
  } catch (_) {
    return false;
  }
});

class NutritionRepository {
  final DioClient people;
  final DioClient nutrition;
  NutritionRepository(this.people, this.nutrition);
  bool get isConfigured => nutritionBaseUrl.isNotEmpty;

  Future<Map<String, dynamic>> health(String id, CancelToken token) async =>
      (await people.getCancelable<Map<String, dynamic>>(
              '/beneficiaries/$id/health-profile',
              cancelToken: token))
          .data!;
  Future<Map<String, dynamic>> patch(String id, int revision,
          Map<String, dynamic> changes, CancelToken token) async =>
      (await people.patchCancelable<Map<String, dynamic>>(
              '/beneficiaries/$id/health-profile',
              data: {'expectedHealthRevision': revision, 'changes': changes},
              cancelToken: token))
          .data!;
  Future<Map<String, dynamic>> capabilities(CancelToken token) async =>
      (await nutrition.getCancelable<Map<String, dynamic>>(
              '/nutrition/capabilities',
              cancelToken: token))
          .data!;
  Future<Map<String, dynamic>> write(String id, String route,
          Map<String, dynamic> data, CancelToken token) async =>
      (await nutrition.postCancelable<Map<String, dynamic>>(
              '/beneficiaries/$id/$route',
              data: data,
              cancelToken: token))
          .data!;
  Future<Map<String, dynamic>> read(
          String id, String route, CancelToken token) async =>
      (await nutrition.getCancelable<Map<String, dynamic>>(
              '/beneficiaries/$id/$route',
              cancelToken: token))
          .data!;
  Future<List<Map<String, dynamic>>> list(
          String id, String route, CancelToken token) async =>
      ((await nutrition.getCancelable<List<dynamic>>(
                      '/beneficiaries/$id/$route',
                      cancelToken: token))
                  .data ??
              [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
}
