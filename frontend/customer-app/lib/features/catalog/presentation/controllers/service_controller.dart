import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_checklist_item_model.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/data/repositories/service_repository.dart';

final serviceStoreProvider =
    AsyncNotifierProvider<ServiceStore, List<ServiceModel>>(ServiceStore.new);

final serviceChecklistProvider = FutureProvider.autoDispose
    .family<List<ServiceChecklistItemModel>, String>((ref, serviceId) {
  return ref.watch(serviceRepositoryProvider).getServiceChecklist(serviceId);
});

class ServiceStore extends AsyncNotifier<List<ServiceModel>> {
  ServiceRepository get _repository => ref.read(serviceRepositoryProvider);

  @override
  Future<List<ServiceModel>> build() async {
    return _fetch();
  }

  Future<List<ServiceModel>> _fetch() async {
    try {
      return await _repository.getServices();
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
