import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/auth/auth_notifier.dart';
import '../data/models/caregiver_model.dart';

final caregiverStoreProvider =
    AsyncNotifierProvider<CaregiverStore, List<CaregiverModel>>(CaregiverStore.new);

class CaregiverStore extends AsyncNotifier<List<CaregiverModel>> {
  @override
  Future<List<CaregiverModel>> build() async {
    // Lắng nghe auth để reset khi logout
    ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (!isAuth) {
        state = const AsyncData([]);
      }
    });
    return _fetch();
  }

  Future<List<CaregiverModel>> _fetch({
    String? city,
    String? district,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final dio = ref.read(dioClientProvider);
      // BE trả paginated: { items: [...], total, page, pageSize }
      final resp = await dio.get<Map<String, dynamic>>(
        '/caregivers',
        query: {
          if (city != null) 'city': city,
          if (district != null) 'district': district,
          'page': page,
          'pageSize': pageSize,
        },
      );
      if (resp.data != null) {
        final items = (resp.data!['items'] as List? ?? []);
        return items
            .map((e) => CaregiverModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch());
  }

  /// Tìm kiếm caregiver theo thành phố/quận
  Future<void> search({String? city, String? district}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(city: city, district: district));
  }
}
