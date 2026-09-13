import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/auth/auth_notifier.dart';
import '../data/models/caregiver_model.dart';

final caregiverStoreProvider =
    AsyncNotifierProvider<CaregiverStore, List<CaregiverModel>>(
        CaregiverStore.new);

class CaregiverStore extends AsyncNotifier<List<CaregiverModel>> {
  int _requestVersion = 0;
  String? _city;
  String? _district;
  @override
  Future<List<CaregiverModel>> build() async {
    // Lắng nghe auth để reset khi logout
    ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (!isAuth) {
        _requestVersion++;
        _city = null;
        _district = null;
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
    return [];
  }

  Future<void> refresh() async {
    await _reload(preserveData: true);
  }

  /// Tìm kiếm caregiver theo thành phố/quận
  Future<void> search({String? city, String? district}) async {
    _city = city;
    _district = district;
    await _reload(preserveData: false);
  }

  Future<void> _reload({required bool preserveData}) async {
    final version = ++_requestVersion;
    final previous = state;
    state = preserveData
        ? const AsyncLoading<List<CaregiverModel>>().copyWithPrevious(previous)
        : const AsyncLoading();
    final result =
        await AsyncValue.guard(() => _fetch(city: _city, district: _district));
    if (version != _requestVersion) return;
    state = preserveData && result.hasError
        ? result.copyWithPrevious(previous)
        : result;
  }
}
