import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:caresitter_customer/features/caregiver/data/repositories/caregiver_repository.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

final caregiverSearchAddressIdProvider = StateProvider<String?>((ref) {
  // Không giữ lựa chọn của tài khoản cũ sau đăng xuất/chuyển tài khoản.
  ref.watch(authStateProvider.select((state) => state.valueOrNull?.userId));
  return null;
});

bool hasCaregiverSearchCoordinates(AddressModel address) {
  final lat = address.latitude;
  final lng = address.longitude;
  return address.isVerified &&
      lat != null &&
      lng != null &&
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;
}

final caregiverSearchAddressProvider =
    FutureProvider<AddressModel?>((ref) async {
  final selectedId = ref.watch(caregiverSearchAddressIdProvider);
  final defaultId =
      ref.watch(profileStoreProvider.select((p) => p.defaultAddressId));
  final addresses = await ref.watch(addressStoreProvider.future);
  final usable = addresses.where(hasCaregiverSearchCoordinates).toList();
  if (selectedId != null) {
    for (final address in usable) {
      if (address.id == selectedId) return address;
    }
    return null;
  }
  for (final address in usable) {
    if (address.id == defaultId) return address;
  }
  return usable.isEmpty ? null : usable.first;
});

final nearbyCaregiversProvider =
    FutureProvider<List<CaregiverModel>>((ref) async {
  final address = await ref.watch(caregiverSearchAddressProvider.future);
  if (address == null) return const [];
  return ref.read(caregiverRepositoryProvider).getCaregivers(
        latitude: address.latitude,
        longitude: address.longitude,
      );
});

// Đọc hồ sơ theo ID để lọc khoảng cách/phân trang không làm mất hồ sơ chi tiết.
final caregiverDetailProvider = FutureProvider.family<CaregiverModel?, String>(
  (ref, id) => ref.read(caregiverRepositoryProvider).getCaregiver(id),
);
