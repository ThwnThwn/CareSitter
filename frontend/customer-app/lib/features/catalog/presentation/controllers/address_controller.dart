import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/catalog/data/repositories/address_repository.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

export 'package:caresitter_customer/features/catalog/data/repositories/address_repository.dart'
    show AddressModel, PlaceSuggestionModel, VerifiedPlaceDetailsModel;

final addressStoreProvider =
    AsyncNotifierProvider<AddressStore, List<AddressModel>>(AddressStore.new);

/// AddressStore — lay va cache danh sach dia chi cua customer tu API.
class AddressStore extends AsyncNotifier<List<AddressModel>> {
  AddressRepository get _repo => ref.read(addressRepositoryProvider);

  @override
  Future<List<AddressModel>> build() async {
    // Auto-reload khi trang thai auth thay doi
    ref.listen(authStateProvider, (prev, next) {
      final isAuth = next.value?.isAuthenticated ?? false;
      if (isAuth) {
        ref.invalidateSelf();
      } else {
        state = const AsyncData([]);
      }
    });

    final isAuth = ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return [];
    return _repo.getAddresses();
  }

  Future<List<PlaceSuggestionModel>> autocompletePlaces(
          {required String input, required String sessionToken}) =>
      _repo.autocompletePlaces(input: input, sessionToken: sessionToken);
  Future<VerifiedPlaceDetailsModel> getPlaceDetails(
          {required String placeId, required String sessionToken}) =>
      _repo.getPlaceDetails(placeId: placeId, sessionToken: sessionToken);

  /// Reload danh sach dia chi tu BE.
  Future<void> refresh() => ref.refresh(addressStoreProvider.future);

  Future<AddressModel> addAddress({
    required String placeId,
    String? sessionToken,
    String? label,
    String? note,
  }) async {
    final created = await _repo.createAddress(
      placeId: placeId,
      sessionToken: sessionToken,
      label: label,
      note: note,
    );
    final current = state.valueOrNull ?? const <AddressModel>[];
    state = AsyncData([created, ...current]);
    return created;
  }

  Future<void> deleteAddress(String id) async {
    await _repo.deleteAddress(id);
    final current = state.valueOrNull ?? const <AddressModel>[];
    state = AsyncData(current.where((address) => address.id != id).toList());
  }

  /// Đặt địa chỉ làm mặc định — gọi PUT /profile/default-address/{id}.
  Future<void> setDefaultAddress(String id) async {
    await _repo.setDefaultAddress(id);
    // Refresh profile để cập nhật defaultAddressId
    await ref.read(profileStoreProvider.notifier).fetchProfile();
  }
}
