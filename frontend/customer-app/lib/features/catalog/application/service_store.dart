import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../data/models/service_model.dart';

final serviceStoreProvider =
    AsyncNotifierProvider<ServiceStore, List<ServiceModel>>(ServiceStore.new);

class ServiceStore extends AsyncNotifier<List<ServiceModel>> {
  @override
  Future<List<ServiceModel>> build() async {
    return _fetch();
  }

  Future<List<ServiceModel>> _fetch() async {
    try {
      final dio = ref.read(dioClientProvider);
      final resp = await dio.get<List<dynamic>>('/services');
      if (resp.data != null) {
        return resp.data!
            .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Lỗi mạng / server → giữ state cũ hoặc empty
    }
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
