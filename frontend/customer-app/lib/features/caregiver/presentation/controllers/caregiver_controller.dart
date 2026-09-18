import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:caresitter_customer/features/caregiver/data/repositories/caregiver_repository.dart';

final caregiverStoreProvider =
    AsyncNotifierProvider<CaregiverStore, List<CaregiverModel>>(
        CaregiverStore.new);

class CaregiverStore extends AsyncNotifier<List<CaregiverModel>> {
  CaregiverRepository get _repository => ref.read(caregiverRepositoryProvider);

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
    return _repository.getCaregivers(
      city: city,
      district: district,
      page: page,
      pageSize: pageSize,
    );
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
