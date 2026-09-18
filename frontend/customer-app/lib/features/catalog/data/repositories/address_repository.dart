import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/features/catalog/data/models/address_model.dart';

export 'package:caresitter_customer/features/catalog/data/models/address_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ref.read(dioClientProvider)),
);

/// Repository goi API quan ly dia chi cua customer.
class AddressRepository {
  final DioClient _dio;
  const AddressRepository(this._dio);

  /// Lay toan bo dia chi da luu cua user hien tai.
  Future<List<AddressModel>> getAddresses() async {
    final resp = await _dio.get<List<dynamic>>(ApiPaths.addresses);
    final data = resp.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AddressModel.fromJson)
        .toList();
  }

  Future<AddressModel> createAddress({
    required String placeId,
    String? sessionToken,
    String? label,
    String? note,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.addresses,
      data: {
        'PlaceId': placeId,
        if (sessionToken != null && sessionToken.trim().isNotEmpty)
          'SessionToken': sessionToken.trim(),
        if (label != null && label.trim().isNotEmpty) 'Label': label.trim(),
        if (note != null && note.trim().isNotEmpty) 'Note': note.trim(),
      },
    );
    return AddressModel.fromJson(resp.data ?? const {});
  }

  Future<List<PlaceSuggestionModel>> autocompletePlaces({
    required String input,
    required String sessionToken,
  }) async {
    final resp = await _dio.get<List<dynamic>>(
      ApiPaths.addressAutocomplete,
      query: {
        'input': input,
        'sessionToken': sessionToken,
      },
    );
    final data = resp.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(PlaceSuggestionModel.fromJson)
        .where((item) => item.placeId.isNotEmpty)
        .toList();
  }

  Future<VerifiedPlaceDetailsModel> getPlaceDetails({
    required String placeId,
    required String sessionToken,
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      ApiPaths.addressPlace(placeId),
      query: {'sessionToken': sessionToken},
    );
    return VerifiedPlaceDetailsModel.fromJson(resp.data ?? const {});
  }

  Future<void> deleteAddress(String id) async {
    await _dio.delete<void>(ApiPaths.addressById(id));
  }

  Future<void> setDefaultAddress(String id) async {
    await _dio.put<void>('/profile/default-address/$id');
  }
}
